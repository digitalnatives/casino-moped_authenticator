require 'spec_helper'
require 'casino/moped_authenticator'

module CASino
  describe MopedAuthenticator do

    let(:pepper) { nil }
    let(:extra_attributes) {{ email: 'mail_address' }}
    let(:options) {{
      database_url: 'mongodb://localhost:27017/my_db?safe=true',
      collection: 'users',
      username_column: 'username',
      password_column: 'password',
      pepper: pepper,
      extra_attributes: extra_attributes
    }}

    subject { described_class.new(options) }

    before do
      create_user(
        'test',
        '$5$cegeasjoos$vPX5AwDqOTGocGjehr7k1IYp6Kt.U4FmMUa.1l6NrzD', # password: testpassword
        mail_address: 'mail@example.org'
      )
    end
    after { @session.drop }

    describe '#validate' do

      context 'valid username' do
        context 'valid password' do
          it 'returns the username' do
            subject.validate('test', 'testpassword')[:username].should eq('test')
          end

          it 'returns the extra attributes' do
            subject.validate('test', 'testpassword')[:extra_attributes][:email].should eq('mail@example.org')
          end

          context 'when no extra attributes given' do
            let(:extra_attributes) { nil }

            it 'returns an empty hash for extra attributes' do
              subject.validate('test', 'testpassword')[:extra_attributes].should eq({})
            end
          end
        end

        context 'invalid password' do
          it 'returns false' do
            subject.validate('test', 'wrongpassword').should eq(false)
          end
        end

        context 'NULL password field' do
          it 'returns false' do
            update_user_pw 'test', nil

            subject.validate('test', 'wrongpassword').should eq(false)
          end
        end

        context 'empty password field' do
          it 'returns false' do
            update_user_pw 'test', ''

            subject.validate('test', 'wrongpassword').should eq(false)
          end
        end
      end

      context 'invalid username' do
        it 'returns false' do
          subject.validate('does-not-exist', 'testpassword').should eq(false)
        end
      end

      context 'support for bcrypt' do
        it 'is able to handle bcrypt password hashes' do
          create_user(
            'test2',
            '$2a$10$dRFLSkYedQ05sqMs3b265e0nnJSoa9RhbpKXU79FDPVeuS1qBG7Jq', # password: testpassword2
            mail_address: 'mail@example.org')
          subject.validate('test2', 'testpassword2').should be_instance_of(Hash)
        end
      end

      context 'support for bcrypt with pepper' do
        let(:pepper) { 'abcdefg' }

        it 'is able to handle bcrypt password hashes' do
          create_user(
            'test3',
            '$2a$10$ndCGPWg5JFMQH/Kl6xKe.OGNaiG7CFIAVsgAOJU75Q6g5/FpY5eX6', # password: testpassword3, pepper: abcdefg
            mail_address: 'mail@example.org')
          subject.validate('test3', 'testpassword3').should be_instance_of(Hash)
        end
      end

      context 'support for phpass' do
        it 'is able to handle phpass password hashes' do
          create_user(
            'test4',
            '$P$9IQRaTwmfeRo7ud9Fh4E2PdI0S3r.L0', # password: test12345
            mail_address: 'mail@example.org')
          subject.validate('test4', 'test12345').should be_instance_of(Hash)
        end
      end

      describe 'extra_attributes' do
        let(:extra_attributes) {{
          id: '_id',
          email: 'mail_address',
          roles: 'roles',
          level: 'level',
        }}

        it 'returns the bson id as a string' do
          create_user(
            'test_attributes',
            '$5$cegeasjoos$vPX5AwDqOTGocGjehr7k1IYp6Kt.U4FmMUa.1l6NrzD', # password: testpassword
            mail_address: 'mail@example.org',
            roles: ['admin', 'agent'],
            level: 26,
          )
          data = subject.validate('test_attributes', 'testpassword')
          expect(data[:extra_attributes][:email]).to eq 'mail@example.org'
          expect(data[:extra_attributes][:roles]).to eq ['admin', 'agent']
          expect(data[:extra_attributes][:level]).to eq 26
          expect(data[:extra_attributes][:id]).to eq user_with_name('test_attributes')['_id'].to_s
        end
      end

    end

    def create_user(username, password, extra = {})
      session[options[:collection]].insert({
        username: username,
        password: password,
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
end
