# Atlassian Confluence Importer Plugin for DocPad

<!-- BADGES/ -->

[![Build Status](http://img.shields.io/travis-ci/phoenixtechpubs/docpad-plugin-conflux.png?branch=master)](http://travis-ci.org/phoenixtechpubs/docpad-plugin-conflux "Check this project's build status on TravisCI")
[![NPM version](http://badge.fury.io/js/docpad-plugin-conflux.png)](https://npmjs.org/package/docpad-plugin-conflux "View this project on NPM")
[![Dependency Status](https://david-dm.org/phoenixtechpubs/docpad-plugin-conflux.svg)](https://david-dm.org/phoenixtechpubs/docpad-plugin-conflux)
[![devDependency Status](https://david-dm.org/phoenixtechpubs/docpad-plugin-conflux/dev-status.svg)](https://david-dm.org/phoenixtechpubs/docpad-plugin-conflux#info=devDependencies)
[![peerDependency Status](https://david-dm.org/phoenixtechpubs/docpad-plugin-conflux/peer-status.svg)](https://david-dm.org/phoenixtechpubs/docpad-plugin-conflux#info=peerDependencies)

<!-- /BADGES -->

Import
[Atlassian Confluence](https://www.atlassian.com/software/confluence/)
spaces into [DocPad](http://docpad.org) collections.  Forked from
[docpad-plugin-tumblr](https://github.com/docpad/docpad-plugin-tumblr/),
with modifications and improvements from
[docpad-plugin-mongodb](https://github.com/nfriedly/docpad-plugin-mongodb/).

## Install

```
docpad install conflux
```

## Configure

### Specify your Confluence site, space, and login credentials

Specify your Confluence site with `CONFLUX_SITE` (e.g.,
`http://confluence.example.org`), your space key with
`CONFLUX_SPACE_KEY` and your login credentials with `CONFLUX_USER` and
`CONFLUX_PW` in either your
[`.env` configuration file](http://docpad.org/docs/config#environment-configuration-file)
like so:

```
CONFLUX_SITE=http://confluence.example.org
CONFLUX_SPACE_KEY=SPACE1
CONFLUX_USER=user1
CONFLUX_PW=password1
```

Or in your [docpad configuration file](http://docpad.org/docs/config):

``` coffee
plugins:
  conflux:
    collections: [
      site: 'http://confluence.example.org'
      spaceKey: 'SPACE1'
      user: 'user1'
      pass: 'password1'
    ]
```

### Customize the output

Here's a more complex example:

``` coffee
plugins:
  conflux:
    collectionDefaults:
      site: 'http://confluence.example.org'
      user: 'user1'
      pass: 'password1'
    collections: [
      {
        spaceKey: 'SPACE1'
        collectionName: 'docs'
        relativeDirPath: 'docs'
        extension: '.html.eco'
        injectDocumentHelper: (document) ->
          document.setMeta(
            layout: 'default'
            tags: (document.get('tags') or [])
          )
      },
      {
        spaceKey: 'SPACE2'
        collectionName: 'blog'
        relativeDirPath: 'posts'
        extension: '.html.eco'
        injectDocumentHelper: (document) ->
          document.setMeta(
            layout: 'default'
            tags: (document.get('tags') or [])
          )
      }
    ]
```

#### Configuration details

Each configuration object in `collections` inherits default values
from `collectionDefaults` and then from the built-in defaults:

``` coffee
collectionDefaults:
  site: process.env.CONFLUX_SITE
  spaceKey: process.env.CONFLUX_SPACE_KEY
  user: process.env.CONFLUX_USER
  pw: process.env.CONFLUX_PW
  collectionName: 'conflux'
  relativeDirPath: null # defaults to collectionName
  extension: '.json'
  injectDocumentHelper: null
  sort: null # http://documentcloud.github.io/backbone/#Collection-comparator
  meta: {}
```

- `collectionName` - the name of the collection and also the default
  directory for the imported documents.  The default is `conflux`. You
  can customize this using the `relativeDirPath` plugin configuration
  option.

- `extension` - Use this option to customize the extension for
  imported documents.  The default is `.json`.

- `injectDocumentHelper` - Use this option to customize the content of
  the imported documents.  Define a function which takes in a single
  [Document Model](https://github.com/bevry/docpad/blob/master/src/lib/models/document.coffee).
  You can access the Confluence JSON data from the `conflux` object.  For example:

  ``` coffee
  docpadConfig = {
    plugins:
      conflux:
        collectionDefaults:
          injectDocumentHelper: (document) ->
            document.setMeta(
              data: adjustSource document.get('conflux').body.view.value
              layout: 'default'
              tags: (document.get('tags') or [])
            )
  }
  adjustSource = (text) ->
    # Images use cachr plugin
    text = text.replace(/src="(\/download\/(attachments|thumbnails)\/.+?)"/g,
      "src=\"<%=@cachr('#{site}$1')%>\"")
    # Inter-page links
    text = text.replace(/href="\/display\/(.+?)\/(.+?)">/g,
      'href="../$1/$2.html">')
    # Code blocks
    text = text.replace(/<script type="syntaxhighlighter".*<!\[CDATA\[/g,
      '<pre><code>')
    text = text.replace(/]]><\/script>/g,
      '</code></pre>')
    # Note icons
    text = text.replace(/<span class="aui-icon icon-hint">Icon/g,
      '<span class="fa fa-info-circle">')
    text = text.replace(/<span class="aui-icon icon-warning">Icon/g,
      '<span class="fa fa-warning">')
    text = text.replace(/<span class="aui-icon icon-sucess">Icon/g,
      '<span class="fa fa-check-circle">')
    text = text.replace(/<span class="aui-icon icon-problem">Icon/g,
      '<span class="fa fa-exclamation-circle">')
    return text
  ```

### Create a file listing

As imported documents are just like normal documents, you can also
list them just as you would other documents.  Here is an example of an
`index.html.eco` file that renders the titles and links to all the
imported documents:

``` erb
<h2>Confluence:</h2>
<ul><% for file in @getFilesAtPath('conflux/').toJSON(): %>
	<li>
		<a href="<%= file.url %>"><%= file.title %></a>
	</li>
<% end %></ul>
```

<!-- HISTORY/ -->

## History

See the change history in the
[`HISTORY.md` file](https://github.com/phoenixtechpubs/docpad-plugin-conflux/blob/master/HISTORY.md#files).

<!-- /HISTORY -->

<!-- CONTRIBUTE/ -->

## Contribute

See how you can contribute in the
[`CONTRIBUTING.md` file](https://github.com/phoenixtechpubs/docpad-plugin-conflux/blob/master/CONTRIBUTING.md#files).

<!-- /CONTRIBUTE -->

<!-- BACKERS/ -->

<!-- /BACKERS -->

<!-- LICENSE/ -->

## License

Licensed under the incredibly
[permissive](http://en.wikipedia.org/wiki/Permissive_free_software_licence)
[MIT license](http://creativecommons.org/licenses/MIT/).

&copy; 2015 Phoenix Technical Publications <info@phoenixtechpubs.com>
(http://phoenixtechpubs.com)

<!-- /LICENSE -->


