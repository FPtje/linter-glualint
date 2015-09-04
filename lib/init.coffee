{BufferedProcess, CompositeDisposable} = require 'atom'
{XRegExp}             = require 'xregexp'
{Process}             = require 'process'

@config =
  executable:
    type: 'string'
    default: 'glualint'
    description: "The executable path to glualint. Leave as 'glualint' if glualint is on your system's PATH."

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

@deactivate = =>
  @subscriptions.dispose()

runPrettyPrint = (editor, selection) =>
    result = []
    process = new BufferedProcess
        command: @executablePath
        options: {stdio: ['pipe', null, null]}
        args: ['--pretty-print']
        stderr: (data) ->
          result.push data
        stdout: (data) ->
          result.push data
        exit: (code) ->
          info = result.join('')
          return unless info
          selection.insertText(info, {select: true})
          selection.autoIndentSelectedRows()

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

matchError = (fp, match) ->
  line = Number(match.line) - 1
  col  = Number(match.col) - 1
  type: if match.warning then 'Warning' else 'Error',
  text: match.message,
  filePath: fp,
  range: [[line, col], [line, col + 1]]

regex = '^.+?: \\[((?<error>Error)|(?<warning>Warning))\\] ' +
      'line (?<line>\\d+), column (?<col>\\d+): ' +
      '(?<message>.+)'

infoErrors = (fp, info) ->
  if (!info)
    return []
  errors = []
  regex = XRegExp regex
  for msg in info.split('\n')
    XRegExp.forEach msg, regex, (match, i) ->
      e = matchError(fp, match)
      errors.push(e)
  return errors

@provideLinter = =>
  helpers = require('atom-linter')
  provider =
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
