insertImageViewModule = require "./insert-image-view"
# uploader = require "qiniu"

fs = require 'fs'
path = require 'path'
mkdirp = require 'mkdirp'
md5 = require 'md5'
PKG = require '../package.json'

TAG_TEXT_EDITOR = 'ATOM-TEXT-EDITOR'
SAVE_TYPE_BASE64 = 'base64'
SAVE_TYPE_FILE = 'file'
SAVE_TYPE_FILE_IN_FOLDER = 'file in folder'
SAVE_TYPE_QINIU = 'qiniu'
FILE_EXT = ['.md', '.markdown', '.mdown', '.mkd', '.mkdown']

module.exports = Markclip =
  config:
    saveType: 'file':
      type: 'string'
      description: 'Where to save the clipboard image file'
      default: SAVE_TYPE_BASE64
      enum: [SAVE_TYPE_BASE64, SAVE_TYPE_FILE, SAVE_TYPE_FILE_IN_FOLDER]
    uploader:
      title: "uploader"
      type: 'string'
      description: "uploader plugin for upload file"
      default: "qiniu-uploader"

  handleCtrlVEvent: () ->
    textEditor = atom.workspace.getActiveTextEditor()
    # do nothing if there is no ActiveTextEditor
    return if !textEditor

    # CHECK: do nothing if no image
    clipboard = require('clipboard')
    img = clipboard.readImage()
    return if img.isEmpty()

    # CHECK: do nothing with unsaved file
    filePath = textEditor.getPath()
    if not filePath
      atom.notifications.addWarning(PKG.name + ': Markdown file NOT saved', {
        detail: 'save your file as ' + FILE_EXT.map((n) => '"' + n + '"').join(', ')
      })
      return

    # CHECK: file type should in FILE_EXT
    filePathObj = path.parse(filePath)
    return if FILE_EXT.indexOf(filePathObj.ext) < 0

    saveType = atom.config.get('markclip.saveType')
    atom.notifications.addWarning(saveType+"XXXXXXx")
    # IF: save as a file
    # atom.notifications.addWarning("aaa")
    saveType = 'qiniu'
    atom.notifications.addWarning(saveType)
    if (saveType == SAVE_TYPE_FILE_IN_FOLDER || saveType == SAVE_TYPE_FILE)
      imgFileDir = filePathObj.dir
      # IF: SAVE IN FOLDER, create it
      if saveType == SAVE_TYPE_FILE_IN_FOLDER
        imgFileDir = path.join(imgFileDir, filePathObj.name)
        mkdirp.sync(imgFileDir)
      # create file with md5 name
      imgFilePath = path.join(imgFileDir, md5(img.toDataUrl()).replace('=', '') + '.png')
      fs.writeFileSync(imgFilePath, img.toPng());
      @insertImgIntoEditor(textEditor, path.relative(filePathObj.dir, imgFilePath))
    # IF: save as base64
    else if saveType="qiniu"
      uploaderName = atom.config.get('markclip.uploader')
      uploaderPkg = atom.packages.getLoadedPackage(uploaderName)
      atom.notifications.addWarning(uploaderPkg+ "xx")
      if not uploaderPkg
        atom.notifications.addWarning('markdown-assistant: uploader not found',{
          detail: "package \"#{uploaderName}\" not found!" +
            "\nHow to Fix:" +
            "\ninstall this package OR change uploader in markdown-assistant's settings"
        })
        return

      uploader = uploaderPkg?.mainModule
      if not uploader
        uploader = require(uploaderPkg.path)
        uploaderIns = uploader.instance()

      try


        uploadFn = (callback)->
          uploaderIns.upload(img.toPng(), 'png', callback)

        insertImageViewInstance = new insertImageViewModule()
        insertImageViewInstance.display(uploadFn)
      catch e
        # add uploadName for trace uploader package error in feedback
        e.message += " [uploaderName=#{uploaderName}]"
        throw new Error(e)

    else
      @insertImgIntoEditor(textEditor, img.toDataUrl())

  insertImgIntoEditor: (textEditor, src) ->
    textEditor.insertText('![](' + src + ')\n')

  activate: (state) ->
    # bind keymaps
    atom.keymaps.onDidMatchBinding((e) =>
      # CHECK: target is TAG_TEXT_EDITOR
      return if ((e.keyboardEventTarget || '').tagName || '') != TAG_TEXT_EDITOR
      # CHECK: cmd-v or ctrl-v
      if e.keystrokes == 'ctrl-v' || e.keystrokes == 'cmd-v'
        @handleCtrlVEvent()
    )
