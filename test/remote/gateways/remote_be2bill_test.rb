# encoding: utf-8
require 'test_helper'

class RemoteBe2billTest < Test::Unit::TestCase

  def setup
    @gateway = Be2billGateway.new(fixtures(:be2bill))

    @amount = 1000
    @credit_card = credit_card('5555556778250000')
    @declined_card = credit_card('5555557376384001')

    @options = {
      :order_id         => 1,
      :address          => address,
      :customer         => 'Guest #42',
      :description      => 'A ski pass from SkiWallet',
      :client_useragent => 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.11 (KHTML, like Gecko) Ubuntu Chromium/23.0.1271.97 Chrome/23.0.1271.97 Safari/537.11',
      :client_ip        => '42.42.42.42',
      :client_email     => 'georges.abitbol@alpine-lab.com'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal response.params['EXECCODE'], '0000'
  end

  def test_successful_with_utf8_encoding
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:customer => 'Pétère et Stévène'))
    assert_success response
    assert_equal response.params['EXECCODE'], '0000'
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal response.params['EXECCODE'], '4001'
  end

  # def test_authorize_and_capture
  #   amount = @amount
  #   assert auth = @gateway.authorize(amount, @credit_card, @options)
  #   assert_success auth
  #   assert_equal 'Success', auth.message
  #   assert auth.authorization
  #   assert capture = @gateway.capture(amount, auth.authorization)
  #   assert_success capture
  # end

  # def test_failed_capture
  #   assert response = @gateway.capture(@amount, '')
  #   assert_failure response
  #   assert_equal 'REPLACE WITH GATEWAY FAILURE MESSAGE', response.message
  # end

  def test_invalid_login
    gateway = Be2billGateway.new(:login => '', :password => '')
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal response.params['EXECCODE'], '1001'
  end
end
