require 'spec_helper'
require 'casino/moped_authenticator'
require 'digest'
require 'bcrypt'

describe 'Nested Attributes' do

  let(:options) do
    {
      database_url: 'mongodb://localhost:27017/my_nested_db?safe=true',
      collection: 'users',
      username_column: 'emails.address',
      password_column: 'services.password.bcrypt',
      additional_digest: 'sha256',
      extra_attributes: { roles: 'roles' }
    }
  end

  let(:password) {  'testpassword' }
  let(:bcrypted_password) { BCrypt::Password.create(Digest::SHA256.hexdigest(password)) } # This is standard in Node Bcrypt
  let(:email_address) {  'test@example.com' }
  let(:roles) { %w(admin user) }

  subject { CASino::MopedAuthenticator.new(options) }

  before do
    create_user(email_address, bcrypted_password, roles: roles)
  end
  after { @session.drop }

  describe '#validate' do

    context 'valid username' do
      context 'valid password' do
        it 'returns the username' do
          subject.validate(email_address, password)[:username].should eq(email_address)
        end

        it 'returns the extra attributes' do
          subject.validate(email_address, password)[:extra_attributes][:roles].should eq(roles)
        end
      end

      context 'invalid password' do
        it 'returns false' do
          subject.validate(email_address, 'wrong').should eq(false)
        end
      end

      context 'NULL password field' do
        it 'returns false' do
          update_user_pw 'test', nil

          subject.validate(email_address, 'wrong').should eq(false)
        end
      end

      context 'empty password field' do
        it 'returns false' do
          update_user_pw 'test', ''

          subject.validate(email_address, 'wrong').should eq(false)
        end
      end
    end

    context 'invalid username' do
      it 'returns false' do
        subject.validate('wrong@example.com', password).should eq(false)
      end
    end
  end

  def create_user(email_address, bcrypted_password, extra = {})
    session[options[:collection]].insert({
      emails: [{ address: email_address }],
      services: { password: { bcrypt: bcrypted_password } }
    }.merge(extra))
  end

  def update_user_pw(username, new_password)
    session[options[:collection]].find(username: username).update(password: new_password)
  end

  def user_with_name(username)
    session[options[:collection]].find(username: username).first
  end

  def session
    @session ||= ::Moped::Session.connect(options[:database_url])
  end
end
