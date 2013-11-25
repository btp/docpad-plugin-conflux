# Prepare
{TaskGroup} = require('taskgroup')
eachr = require('eachr')

# Export
module.exports = (BasePlugin) ->
	# Define
	class TumblrPlugin extends BasePlugin
		# Name
		name: 'tumblr'

		# Config
		config:
			blog: process.env.TUMBLR_BLOG
			apiKey: process.env.TUMBLR_API_KEY
			relativeDirPath: "tumblr"
			extension: ".json"
			injectDocumentHelper: null
			collectionName: "tumblr"

		# =============================
		# Events

		# Extend Collections
		# Create our live collection for our tags
		extendCollections: ->
			# Prepare
			config = @getConfig()
			docpad = @docpad

			# Check
			if config.collectionName
				# Create the collection
				tagsCollection = docpad.getFiles({relativeDirPath: $startsWith: config.relativeDirPath}, [title:1])

				# Set the collection
				docpad.setCollection(config.collectionName, tagsCollection)

			# Chain
			@

		# Fetch our Tumblr Posts
		# next(err,tumblrPosts)
		fetchTumblrData: (opts={},next) ->
			# Prepare
			config = @getConfig()
			feedr = @feedr ?= new (require('feedr').Feedr)

			# Check
			if !config.blog or !config.apiKey
				err = new Error('Tumblr plugin is not configured correctly')
				return next(err)

			# Prepare
			{blog,apiKey} = config
			blog = blog+'.tumblr.com'  if blog.indexOf('.') is -1

			# Prepare
			tumblrUrl = "http://api.tumblr.com/v2/blog/#{blog}/posts?api_key=#{escape apiKey}"
			tumblrPosts = []

			# Fetch the first feed which is the initial page
			feedr.readFeed tumblrUrl, {parse:'json'}, (err,feedData) ->
				# Check
				return next(err)  if err

				# Check the feed's data
				unless feedData.response?.posts
					err = new Error("Tumblr post data was empty, here's the result: "+JSON.stringify(feedData))
					return next(err)

				# Concat the posts
				for tumblrPost in (feedData.response.posts or [])
					tumblrPosts.push(tumblrPost)

				# Fetch the remaining pages as their own individual feeds
				feeds = []
				for offset in [20...feedData.response.blog.posts] by 20
					feeds.push("#{tumblrUrl}&offset=#{offset}")
				feedr.readFeeds feeds, {parse:'json'}, (err,feedsData) ->
					# Check
					return next(err)  if err

					# Cycle each feed
					for feedData in feedsData
						# Check the feed's data
						unless feedData.response?.posts
							err = new Error("Tumblr post data was empty, here's the result: "+JSON.stringify(feedData))
							return next(err)

						# Concat the posts
						for tumblrPost in (feedData.response.posts or [])
							tumblrPosts.push(tumblrPost)

					# Done
					return next(null, tumblrPosts)

			# Chain
			@


		# =============================
		# Events

		# Populate Collections
		# Import Tumblr Data into the Database
		populateCollections: (opts,next) ->
			# Prepare
			me = @
			config = @getConfig()
			docpad = @docpad
			database = docpad.getDatabase()
			docpadConfig = docpad.getConfig()

			# Imported
			imported = 0

			# Log
			docpad.log('info', "Importing Tumblr posts...")

			# Fetch
			@fetchTumblrData null, (err,tumblrPosts) ->
				# Check
				return next(err)  if err

				# Inject our posts
				eachr tumblrPosts, (tumblrPost,i) ->
					# Prepare
					tumblrPostId = parseInt(tumblrPost.id, 10)
					tumblrPostMtime = new Date(tumblrPost.date)
					tumblrPostDate = new Date(tumblrPost.date)

					# Fetch
					document = docpad.getFile({tumblrId:tumblrPostId})
					documentTime = document?.get('mtime') or null

					# Compare
					if documentTime and documentTime.toString() is tumblrPostMtime.toString()
						# Log
						docpad.log('debug', "Skipped   tumblr post #{i}/#{tumblrPosts.length}: #{document.getFilePath()}")

						# Skip
						return

					# Prepare
					documentAttributes =
						data: JSON.stringify(tumblrPost, null, '\t')
						meta:
							tumblrId: tumblrPostId
							tumblrType: tumblrPost.type
							tumblr: tumblrPost
							title: (tumblrPost.title or tumblrPost.track_name or tumblrPost.text or tumblrPost.caption or '').replace(/<(?:.|\n)*?>/gm, '')
							date: tumblrPostDate
							mtime: tumblrPostMtime
							tags: (tumblrPost.tags or []).concat([tumblrPost.type])
							relativePath: "#{config.relativeDirPath}/#{tumblrPost.type}/#{tumblrPost.id}#{config.extension}"

					# Log
					docpad.log('debug', "Importing tumblr post #{i}/#{tumblrPosts.length}: #{documentAttributes.meta.relativePath}")

					# Existing document
					if document?
						document.set(documentAttributes)

					# New Document
					else
						# Create document from opts
						document = docpad.createDocument(documentAttributes)

					# Inject document helper
					config.injectDocumentHelper?.call(me, document)

					# Add it to the database (with b/c compat)
					docpad.addModel?(document) or docpad.getDatabase().add(document)
					++imported

					# Log
					docpad.log('debug', "Imported  tumblr post #{i}/#{tumblrPosts.length}: #{document.getFilePath()}")

				# Log
				docpad.log('info', "Imported #{imported}/#{tumblrPosts.length} Tumblr posts...")

				# Complete
				return next()

			# Chain
			@

	###
	writeFiles: (opts,next) ->
		if @getConfig().writeSourcEfiles
			.writeSource()
	###