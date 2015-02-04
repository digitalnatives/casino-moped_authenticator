require 'moped'
require 'unix_crypt'
require 'bcrypt'
require 'phpass'

class CASino::MopedAuthenticator
  # @param [Hash] options
  def initialize(options)
    @options = options
    @connection = Moped::Session.connect(options[:database_url])
  end

  def validate(username, password)
    user = collection.find(@options[:username_column] => username).first
    return false unless user

    username_from_database = get_nested(user, @options[:username_column], true)
    password_from_database = get_nested(user, @options[:password_column], true)

    if valid_password?(password, password_from_database)
      { username: username_from_database, extra_attributes: extra_attributes(user) }
    else
      false
    end
  end

  private

  def get_nested(item, key_string, first = false)
    return_item = item.dup

    return return_item unless item.is_a?(Hash)

    key_string.split('.').each do |key_part|
      result = return_item[key_part]
      result = result[0] if result.is_a?(Array) && first
      return_item = result
    end

    return_item
  end

  def valid_password?(password, password_from_database)
    return false if password_from_database.to_s.strip == ''

    # SHA256 password if enabled
    password = Digest::SHA256.hexdigest(password) if @options[:additional_digest] && @options[:additional_digest] == 'sha256'

    magic = password_from_database.split('$')[1]
    case magic
    when /\A2a?\z/
      valid_password_with_bcrypt?(password, password_from_database)
    when /\AH\z/, /\AP\z/
      valid_password_with_phpass?(password, password_from_database)
    else
      valid_password_with_unix_crypt?(password, password_from_database)
    end
  end

  def valid_password_with_bcrypt?(password, password_from_database)
    password_with_pepper = password + @options[:pepper].to_s
    BCrypt::Password.new(password_from_database) == password_with_pepper
  end

  def valid_password_with_unix_crypt?(password, password_from_database)
    UnixCrypt.valid?(password, password_from_database)
  end

  def valid_password_with_phpass?(password, password_from_database)
    Phpass.new.check(password, password_from_database)
  end

  def extra_attributes(user)
    extra_attributes_option.each_with_object({}) do |(attribute_name, database_column), attributes|
      value = get_nested(user, database_column)
      value = value.to_s if value.is_a?(Moped::BSON::ObjectId)
      attributes[attribute_name] = value
    end
  end

  def extra_attributes_option
    @options[:extra_attributes] || {}
  end

  def collection
    @connection[@options[:collection]]
  end
end
