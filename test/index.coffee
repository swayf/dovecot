# Load modules
Lab = require 'lab'
Sinon = require 'sinon'
Hapi = require 'hapi'
Path = require 'path'
iced = require('iced-coffee-script').iced


# Test shortcuts
expect = Lab.expect
before = Lab.before
after = Lab.after
describe = Lab.experiment
it = Lab.test


old = process._fatalException
process._fatalException = (err) ->
    stack = iced.stackWalk()
    if stack.length
        err.stack += '\nIced callback trace:\n'
        err.stack += stack.join('\n')
    old(err)


describe 'dovecot', ->

    server = new Hapi.Server(8000)

    dovecot = require '..'
    requestStub = {}
    sendEmailStub = null

    it 'register plugin', (done) ->

        class EctWrapper
            constructor: (@ect) ->
            compile: (template, data) =>
                filename = data.filename
                compiled = (context, options) =>
                    @ect.render filename, context

        options =
            views:
                engines:
                    jade:
                        module: require 'jade'
                    ect:
                        module: new EctWrapper require('ect')
                            open:   '{{'
                            close:  '}}'
                path:           './templates'
                basePath:       Path.join __dirname

        server.pack.require '..', options, (err) ->
            expect(err).to.not.exist
            sendEmailStub = Sinon.stub dovecot.mailer.mailTransport, 'sendMail'
            done()


    it 'dovecot simple sendEmail', (done) ->
        mail =
            fields:
                to: 'test@test.com'
                text:'test'

        sendEmailStub.withArgs(mail.fields).callsArgWithAsync 1, null, 'ok'
        server.plugins.dovecot.sendEmail requestStub, mail, (result) ->
            expect(result).to.equal('ok')
            done()


    it 'dovecot sendEmail with retry', (done) ->
        mail2 =
            fields:
                to: 'test2@test.com'
                text:'test2'

            onFailure:
                retries: 1
                minTimeout: 500
                maxTimeout: 1500
                factor: 2
                randomize: false

        sendEmailStub.withArgs(mail2.fields).callsArgWithAsync 1, 'Error', null

        server.plugins.dovecot.sendEmail requestStub, mail2, (result) ->
            expect(result.isBoom).to.equal(true)
            expect(result.message).to.equal('Error')
            expect(result.data.length).to.equal 2
            done()


    it 'send email with jade template generation', (done) ->

        sendEmailStub.callsArgWithAsync 1, null, 'ok'

        mail =
            template:
                filename: 'register.jade'
                context:
                    app:
                        host_name:      'example.com'
                    registration_token: '1234abcd'
                    subject:            'test'
            fields:
                to: 'test3@test.com'

        server.route
            method: 'GET'
            path: '/'
            handler: (request) ->
                server.plugins.dovecot.sendEmail request, mail, (result) ->
                    expect(result).to.equal 'ok'
                    request.reply()

        server.inject '/', (res) ->
            sentMail = sendEmailStub.lastCall.args[0]
            expect(sentMail.html).to.equal '<h1>test</h1><p>example.com/?token=1234abcd</p>'
            expect(sentMail.to).to.equal 'test3@test.com'
            done()


    it 'send email with ect template generation', (done) ->

        sendEmailStub.callsArgWithAsync 1, null, 'ok'

        mail =
            template:
                filename: 'test.ect'
                context:
                    app:
                        host_name:      'example.com'
                    registration_token: '1234abcd'
                    subject:            'test'
            fields:
                to: 'test3@test.com'

        server.route
            method: 'GET'
            path: '/test'
            handler: (request) ->
                server.plugins.dovecot.sendEmail request, mail, (result) ->
                    expect(result).to.equal 'ok'
                    request.reply()

        server.inject '/test', (res) ->
            sentMail = sendEmailStub.lastCall.args[0]
            expect(sentMail.html).to.equal '<h1>test</h1><p>example.com/?token=1234abcd</p>'
            expect(sentMail.to).to.equal 'test3@test.com'
            done()

