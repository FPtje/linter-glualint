{BufferedProcess, CompositeDisposable, TextBuffer, TextEditor} = require 'atom'
{Process}             = require 'process'

@config =
  executable:
    type: 'string'
    default: 'glualint'
    description: "The path to the glualint executable. Leave as 'glualint' if glualint is on your system's PATH."

  lintOnSave:
    type: 'boolean'
    default: false
    description: "Lint only on file save and not while typing."

@activate = =>
  @subscriptions = new CompositeDisposable
  @subscriptions.add atom.config.observe 'linter-glualint.executable', (executable) =>
    @executablePath = executable

  @subscriptions.add atom.config.observe 'linter-glualint.lintOnSave', (save) =>
    @lintOnSave = save

  atom.commands.add 'atom-workspace', 'linter-glualint:prettyprint': => @prettyprint()
  atom.commands.add 'atom-workspace', 'linter-glualint:lintproject': => @lintproject()
  atom.commands.add 'atom-workspace', 'linter-glualint:findglobalsproject': => @findglobalsproject()

@deactivate = =>
  @subscriptions.dispose()

runPrettyPrint = (editor, selection) =>
    indentation = '--indentation=\'' + editor.getTabText() + '\''
    result = []
    process = new BufferedProcess
        command: @executablePath
        options: {stdio: ['pipe', null, null]}
        args: [indentation, '--pretty-print']
        stderr: (data) ->
          result.push data
        stdout: (data) ->
          result.push data
        exit: (code) ->
          info = result.join('')
          return unless info

          checkpoint = editor.createCheckpoint()
          selection.insertText(info, {select: true})
          selection.autoIndentSelectedRows()
          editor.groupChangesSinceCheckpoint(checkpoint)

    process.onWillThrowError ({error,handle}) ->
        atom.notifications.addError "Failed to run #{@executablePath}",
          detail: "#{error.message}"
          dismissable: true
        handle()

    process.process.stdin.write(selection.getText())
    process.process.stdin.end()

@prettyprint = =>
    editor = atom.workspace.getActivePaneItem()
    selections = editor.getSelections()

    runPrettyPrint(editor, selection) for selection in selections

formatLintProjectString = (str) =>
    pattern = /(.+?):\s(\[((Error)|(Warning))\]\s.*)/g

    dict = {}

    while match = pattern.exec(str)
        fileName = match[1]
        msg = match[2]
        dict[fileName] = if dict[fileName] then dict[fileName] else []
        dict[fileName].push(msg)

    res = []

    for fileName, messages of dict
      res.push(fileName + ":")

      for msg in messages
        res.push("    " + msg)

      res.push ""

    return res.join('\n')

runLintProject = (editor) =>
    projects = atom.project.getPaths()
    result = []

    pane = atom.workspace.getActivePane()

    process = new BufferedProcess
        command: @executablePath
        options: {stdio: [null, null, null]}
        args: projects
        stderr: (data) ->
          result.push data
        stdout: (data) ->
          result.push data
        exit: (code) ->
          info = result.join('')
          atom.workspace.open("")
          .then (edt) ->
            info = if info == "" then "No lint messages" else formatLintProjectString(info)
            edt.setText("Project lint messages: \n\n" + info)


    process.onWillThrowError ({error,handle}) ->
        atom.notifications.addError "Failed to run #{@executablePath}",
          detail: "#{error.message}"
          dismissable: true
        handle()


@lintproject = =>
    editor = atom.workspace.getActivePaneItem()

    runLintProject(editor)


runFindGlobalsProject = (editor) =>
    projects = atom.project.getPaths()
    result = []

    pane = atom.workspace.getActivePane()

    process = new BufferedProcess
        command: @executablePath
        options: {stdio: [null, null, null]}
        args: ["--analyse-globals"].concat(projects)
        stderr: (data) ->
          result.push data
        stdout: (data) ->
          result.push data
        exit: (code) ->
          info = result.join('')
          atom.workspace.open("")
          .then (edt) ->
            info = if info == "" then "No globals found" else info
            edt.setText("Project globals: \n\n" + info)


    process.onWillThrowError ({error,handle}) ->
        atom.notifications.addError "Failed to run #{@executablePath}",
          detail: "#{error.message}"
          dismissable: true
        handle()


@findglobalsproject = =>
    editor = atom.workspace.getActivePaneItem()

    runFindGlobalsProject(editor)

matchError = (fp, match) ->
  line = Number(match[2]) - 1
  col  = Number(match[3]) - 1
  endLine = if match[5] != undefined then Number(match[5]) - 1 else line
  endCol = if match[6] != undefined then Number(match[6]) - 1 else col + 1
  type: if match[1] == 'Warning' then 'Warning' else 'Error',
  text: match[7],
  filePath: fp,
  range: [[line, col], [endLine, endCol]]

regex = '^.+?: \\[(Error|Warning)\\] ' +
      'line (\\d+), column (\\d+)( - line (\\d+), column (\\d+))?: ' +
      '(.+)'

infoErrors = (fp, info) ->
  if (!info)
    return []
  errors = []
  matcher = RegExp regex
  for msg in info.split('\n')
    match = matcher.exec(msg)

    if (match?)
      e = matchError(fp, match)
      errors.push(e)

  return errors

@provideLinter = =>
  helpers = require('atom-linter')
  provider =
    name: 'glualint'
    grammarScopes: ['source.lua']
    scope: 'file'
    lintOnFly: not @lintOnSave
    lint: (textEditor) =>
      return new Promise (resolve, reject) =>
        filePath = textEditor.getPath()
        message  = []

        process = new BufferedProcess
            command: @executablePath
            args: [filePath]
            stderr: (data) ->
              message.push data
            stdout: (data) ->
              message.push data
            exit: (code) ->
              info = message.join('\n').replace(/[\r]/g, '');
              return resolve [] unless info?
              resolve infoErrors(filePath, info)

        process.onWillThrowError ({error,handle}) ->
            atom.notifications.addError "Failed to run #{@executablePath}",
              detail: "#{error.message}"
              dismissable: true
            handle()
            resolve []
