# Load modules
Lab = require("lab")
Sinon = require("sinon")
Hapi = require("hapi")


# Test shortcuts
expect = Lab.expect
before = Lab.before
after = Lab.after
describe = Lab.experiment
it = Lab.test


describe "dovecot", ->

  server = new Hapi.Server()
  await server.pack.require '..', defer err
  expect(err).to.not.exist

  dovecot = require '..'
  sendEmailStub = Sinon.stub dovecot.mailer.mailTransport, 'sendMail'
  requestStub = {}


  it 'dovecot simple sendEmail', (done) ->
    mail =
      options:
        to: 'test@test.com'
        text:'test'

    sendEmailStub.withArgs(mail.options).callsArgWith 1, null, 'ok'

    await server.plugins.dovecot.sendEmail requestStub, mail, defer result

    expect(result).to.equal('ok')
    done()


  it 'dovecot sendEmail with retry', (done) ->
    mail2 =
      options:
        to: 'test2@test.com'
        text:'test2'

      onFailure:
        retries: 1
        minTimeout: 500
        maxTimeout: 1500
        factor: 2
        randomize: false

    sendEmailStub.withArgs(mail2.options).callsArgWith 1, 'Error', null

    await server.plugins.dovecot.sendEmail requestStub, mail2, defer result
    expect(result.isBoom).to.equal(true)
    expect(result.message).to.equal('Error')
    expect(result.data.length).to.equal(2)
    done()