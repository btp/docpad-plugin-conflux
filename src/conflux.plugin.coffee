module.exports = (BasePlugin) ->
  Feedr = require('feedr')
  {TaskGroup} = require('taskgroup')
  _ = require('lodash')

  class ConfluxPlugin extends BasePlugin
    name: 'conflux'

    config:
      collectionDefaults:
        site: process.env.CONFLUX_SITE
        spaceKey: process.env.CONFLUX_SPACE_KEY
        user: process.env.CONFLUX_USER
        pw: process.env.CONFLUX_PW
        relativeDirPath: null # defaults to collectionName
        cleanurls: true
        extension: '.json'
        injectDocumentHelper: null
        collectionName: 'conflux'
        sort: null # http://documentcloud.github.io/backbone/#Collection-comparator
        meta: {}
      collections: []

    # DocPad v6.24.0+ compatible
    # Configuration
    setConfig: ->
      super
      config = @getConfig()

      config.collections = config.collections.map (collection) ->
        return _.defaults(collection, config.collectionDefaults)

      # Chain
      @

    getBasePath: (collectionConfig) ->
      "#{collectionConfig.relativeDirPath or collectionConfig.collectionName}/"

    # Fetch Confluence Space
    # next(err, pages)
    fetchSpace: (collectionConfig, next) ->
      plugin = @
      docpad = @docpad

      {site, spaceKey, user, pw} = collectionConfig

      if !site or !spaceKey or !user or !pw
        err = new Error('Conflux plugin is not configured correctly')
        return next(err)

      # Query options: modified times (expand=version); maximum # of
      # responses (limit=100)
      queryOpts = 'expand=version&limit=100'
      path = "/rest/api/space/#{spaceKey}/content/page?#{queryOpts}"

      feedrOpts =
        parse: 'json'
        requestOptions:
          auth:
            user: user
            pass: pw

      plugin.fetchPageSet feedrOpts, site, path, (err, pages) ->
        return next(err) if err
        return next(null, pages)

    # Fetch set of Confluence Pages
    # next(err, pages)
    fetchPageSet: (feedrOpts, site, path, next) ->
      plugin = @
      docpad = @docpad
      feedr = @feedr ?= new Feedr
      url = "#{site}#{path}&expand=version&os_auth=basic"
      pages = []

      # Fetch
      feedr.readFeed url, feedrOpts, (err, pageSet) ->
        return next(err) if err

        # Check feed data
        unless pageSet.results?
          err = new Error("No pages to fetch; here's the result: " +
            JSON.stringify(pageSet))
          return next(err)

        for page in (pageSet.results or [])
          pages.push(page)

        docpad.log('debug', "# of pages: #{pages.length}")

        # Path with query for next set of pages
        nextPath = pageSet._links.next ? null

        unless nextPath?
          return next(null, pages)

        return plugin.fetchPageSet feedrOpts, site, nextPath, (err, nextPages) ->
          return next(err) if err

          return next(null, pages.concat(nextPages))

    # Fetch Confluence Page
    # next(err, page)
    fetchPage: (collectionConfig, id, next) ->
      docpad = @docpad
      feedr = @feedr ?= new (require('feedr').Feedr)

      {site, spaceKey, user, pw} = collectionConfig

      queryOpts = 'expand=metadata.labels,body.view&os_auth=basic'
      url = "#{site}/rest/api/content/#{id}?#{queryOpts}"

      feedrOpts =
        parse: 'json'
        requestOptions:
          auth:
            user: user
            pass: pw

      # Fetch page
      feedr.readFeed url, feedrOpts, (err, page) ->
        return next(err) if err

        # Check feed data
        unless page.body.view?
          err = new Error("Confluence Page was empty; here's the result: " +
            JSON.stringify(page))
          return next(err)

        # Done
        return next(null, page)

    # Convert JSON from Confluence to DocPad-style document/file model.
    # ``body'' of DocPad document is JSON string of Confluence body.view,
    # ``meta'' includes all Confluence data
    # next(err, document)
    confluxToDocpad: (collectionConfig, page, next) ->
      plugin = @
      docpad = @docpad
      getBasePath = @getBasePath
      extension = collectionConfig.extension
      infix = if collectionConfig.cleanurls? then '/index' else ''

      # Extract metadata
      id = page.id.toString();
      pageMtime = new Date(page.version.when)

      # Fetch
      document = docpad.getFile({confluxId:id})
      documentTime = document?.get('mtime') or null

      # Compare
      if documentTime and documentTime.toString() is pageMtime.toString()
        # Skip page
        return next(null, null)

      # Fetch full page from Confluence
      plugin.fetchPage collectionConfig, id, (err, page) ->
        return next(err) if err

        # Prepare paths
        filename = page.title.replace /\s/g, '+'
        basepath = getBasePath collectionConfig
        pathname = "#{basepath}#{filename}#{infix}#{extension}"
        documentAttributes =
          data: page.body.view.value
          meta: _.defaults(
            {},
            collectionConfig.meta,
            confluxId: id
            confluxCollection: collectionConfig.collectionName
            conflux: page
            title: page.title
            mtime: pageMtime
            tags: page.metadata.labels.results.name
            relativePath: pathname,
          )

        # Existing document
        if document?
          document.set(documentAttributes)

        # New document
        else
          # Create document from opts
          document = docpad.createDocument(documentAttributes)

        # Inject document helper
        collectionConfig.injectDocumentHelper?.call(plugin, document)

        # Load document
        document.action 'load', (err) ->
          return next(err, document) if err

          # Add to database
          docpad.addModel?(document) or docpad.getDatabase().add(document)

          # Complete
          return next(null, document)

        # Return document
        return document

    addConfluxCollectionToDb: (collectionConfig, next) ->
      plugin = @
      docpad = @docpad

      plugin.fetchSpace collectionConfig, (err, pages) ->
        return next(err) if err

        docpad.log('debug', "Fetched #{pages.length} Confluence Pages in
          collection #{collectionConfig.collectionName}; converting ...")

        docTasks = new TaskGroup({concurrency:0}).done (err) ->
          return next(err) if err
          docpad.log('debug', "Converted #{pages.length} Confluence Pages ...")
          next()

        pages.forEach (page) ->
          docTasks.addTask (complete) ->
            docpad.log('debug', "Inserting #{page.id} into database ...")
            plugin.confluxToDocpad collectionConfig, page, (err) ->
              return complete(err) if err
              docpad.log('debug', 'Inserted')
              complete()

        docTasks.run()

    # --------------------------------------------------------------------------
    # Events

    # Populate Collections
    # Import Confluence data into database
    populateCollections: (opts, next) ->
      plugin = @
      docpad = @docpad
      config = @getConfig()

      # Log
      docpad.log('info', 'Importing Confluence pages ...')

      # Run tasks simultaneously (concurrency:0)
      collectionTasks = new TaskGroup(concurrency:0).done (err) ->
        return next(err) if err

        # Log
        docpad.log('info', "Imported all Confluence pages ...")

        # Complete
        return next()

      config.collections.forEach (collectionConfig) ->
        collectionTasks.addTask (complete) ->
          plugin.addConfluxCollectionToDb collectionConfig, (err) ->
            complete(err) if err

            pages = docpad.getFiles {
              confluxCollection: collectionConfig.collectionName
              }, collectionConfig.sort

            # Set collection
            docpad.setCollection(collectionConfig.collectionName, pages)

            docpad.log('info', "Created DocPad collection
               \"#{collectionConfig.collectionName}\" with #{pages.length}
               pages from Confluence")

            complete()

      collectionTasks.run()

      # Chain
      @
