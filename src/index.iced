Nodemailer = require("nodemailer")


class Mailer

  defaults:
    type: 'SMTP'
    transport: {}

    mail:
      onFailure:
        retries: 5
        minTimeout: 2 * 1000
        maxTimeout: 5 * 60 * 1000
        factor: 2
        randomize: true

      template:
        filename: ''
        context: {}
        options: {}

      options: {}


  constructor: (plugin, options) ->
    @plugin = plugin
    @Hapi = plugin.hapi
    @Utils = @Hapi.utils
    @Boom = @Hapi.error
    @log = plugin.log
    @settings = @Utils.applyToDefaults(@defaults, options)
    @mailTransport = Nodemailer.createTransport(@settings.type, @settings.transport)


  sendEmail: (request, mailOptions, next) =>

    mailSettings = @Utils.applyToDefaults(@settings.mail, mailOptions)

    # if template is definded, lets render html email
    if mailSettings.template.filename
      # TODO: write test for html-email rendering
      # TODO: add async render support??
      mailSettings.options.html = request.server._views.render  mailSettings.template.filename,
                                                                mailSettings.template.context,
                                                                mailSettings.template.options
    errors = []
    try_number = 0
    error = ''

    while error? and try_number <= mailSettings.onFailure.retries
      try_number++
      await @mailTransport.sendMail mailSettings.options, defer error, responseStatus
      if error
        errors.push error
        if try_number <= mailSettings.onFailure.retries
          timeout = mailSettings.onFailure.minTimeout * Math.pow mailSettings.onFailure.factor, try_number
          timeout *= (1 + Math.random()) if mailSettings.onFailure.randomize
          await setTimeout defer(), timeout

    if error
      @log ['email', 'plugin', 'error'], errors
      result = @Boom.internal error, errors
    else
      result = responseStatus

    next result if next



exports.register = (plugin, options, next) ->

  exports.mailer = new Mailer plugin, options
  plugin.api "sendEmail", exports.mailer.sendEmail

  next()