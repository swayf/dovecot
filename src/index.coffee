Nodemailer = require 'nodemailer'
assert = require 'assert'

class Mailer

    defaults:
        type: 'SMTP'
        transport: {}

        views:  {}

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

            fields: {}


    constructor: (@plugin, options) ->

        assert @plugin and @plugin.hapi, 'Invalid plugin argument'
        @plugin.hapi.utils.assert @constructor is Mailer, 'Scheme must be instantiated using new'

        @Hapi = plugin.hapi
        @Utils = @Hapi.utils
        @Boom = @Hapi.error
        @log = plugin.log
        @settings = @Utils.applyToDefaults @defaults, options

        @mailTransport = Nodemailer.createTransport @settings.type, @settings.transport


    sendEmail: (request, mailOptions, next) =>

        mailSettings = @Utils.applyToDefaults(@settings.mail, mailOptions)

        # if template is definded, lets render html email
        if mailSettings.template?.filename
            view_manager = request.server.pack._env?.dovecot?.views || request.server._views
            await view_manager.render mailSettings.template.filename,
                mailSettings.template.context,
                mailSettings.template.options,
                defer err, rendered, settings

            if err
                @log ['email', 'plugin', 'error'], err
                return next err

            mailSettings.fields.html = rendered

        errors = []
        try_number = 0
        error = ''

        while error? and try_number <= mailSettings.onFailure.retries
            try_number++
            await @mailTransport.sendMail mailSettings.fields, defer error, responseStatus
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

        next result



is_empty = (obj) ->
    if not obj? or obj.length is 0
        return true

    if obj.length? and obj.length > 0
        return false

    for own key of obj
        return false

    return true


exports.register = (plugin, options, next) ->

    view_initialized = false
    if not is_empty options.views
        plugin.views options.views
        view_initialized = true

    createEmailer = (local_options) ->
        merged_options = plugin.hapi.utils.applyToDefaults options, local_options
        if not view_initialized
            plugin.views merged_options.views
        new Mailer plugin, merged_options

    default_mailer = new Mailer plugin, options

    if process.env.NODE_ENV == 'test'
        exports.mailer = default_mailer

    plugin.expose 'createEmailer', createEmailer
    plugin.expose 'sendEmail',    default_mailer.sendEmail

    next()