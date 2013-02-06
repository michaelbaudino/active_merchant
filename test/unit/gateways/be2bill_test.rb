require 'test_helper'

class Be2billTest < Test::Unit::TestCase
  def setup
    @gateway = Be2billGateway.new(:login => 'login', :password  => 'password')

    @credit_card = credit_card
    @amount = 1000

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

  def test_supported_countries
    assert_equal ['FR'], Be2billGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express], Be2billGateway.supported_cardtypes
  end

  def test_add_amount
    params = {}
    @gateway.send(:add_amount, params, 1000)
    assert_equal params, {:AMOUNT => 1000}
  end

  def test_add_order
    params = {}
    @gateway.send(:add_order, params, :order_id => 1)
    assert_equal params, {:ORDERID => 1}
  end

  def test_add_customer
    params = {}
    options = {
      :customer         => 'Georges Abitbol',
      :client_useragent => 'w3m/ftw',
      :client_ip        => '10.73.73.73',
      :client_email     => 'georges.abitbol@alpine-lab.com'
    }
    @gateway.send(:add_customer, params, options)
    assert_equal params, {
      :CLIENTIDENT     => 'Georges Abitbol',
      :CLIENTUSERAGENT => 'w3m/ftw',
      :CLIENTIP        => '10.73.73.73',
      :CLIENTEMAIL     => 'georges.abitbol@alpine-lab.com'
    }
  end

  def test_add_description
    params = {}
    @gateway.send(:add_description, params, :description => 'A simple description')
    assert_equal params, {:DESCRIPTION => 'A simple description'}
  end

  def test_add_creditcard
    params = {}
    cc = CreditCard.new({
      :number             => '4111111111111111',
      :month              => 9,
      :year               => 2017,
      :first_name         => 'Georges',
      :last_name          => 'Abitbol',
      :verification_value => '123',
      :brand              => 'visa'
    })
    @gateway.send(:add_creditcard, params, cc)
    assert_equal params, {
      :CARDCODE         => '4111111111111111',
      :CARDFULLNAME     => 'Georges Abitbol',
      :CARDVALIDITYDATE => '09-17',
      :CARDCVV          => '123'
    }
  end

  def test_add_3dsecure
    # Valid 3DSecure options
    params = {}
    @gateway.send(:add_3dsecure, params, :'3dsecure' => true, :'3dsecuremode' => 'POPUP')
    assert_equal params, {:'3DSECURE' => 'yes', :'3DSECUREDISPLAYMODE' => 'POPUP'}
    # Another valid 3DSecure options
    params = {}
    @gateway.send(:add_3dsecure, params, :'3dsecure' => 'yes', :'3dsecuremode' => 'popup')
    assert_equal params, {:'3DSECURE' => 'yes', :'3DSECUREDISPLAYMODE' => 'POPUP'}
    # Invalid 3DSecure options
    params = {}
    @gateway.send(:add_3dsecure, params, :'3dsecure' => 'Georges', :'3dsecuremode' => 'Abitbol')
    assert_equal params, {}
  end

  def test_be2bill_digest
    params = {
      :key1 => :value1,
      :key2 => :value2,
      :key3 => :value3
    }
    response = @gateway.send(:be2bill_digest, params)
    assert_equal response, '154f6aec5f22fc6fc1c85a6968a2f6f7e614e666b40b09acbcbfa965fe1c5f9e'
  end

  def test_post_data
    params = {
      :key1 => :value1,
      :key2 => :value2,
      :key3 => :value3
    }
    response = @gateway.send(:post_data, 'payment', params)
    assert_equal response, 'method=payment&params%5Bkey1%5D=value1&params%5Bkey2%5D=value2&params%5Bkey3%5D=value3'
  end

  def test_response_is_valid
    # Valid successful response
    assert @gateway.send(:response_is_valid?, {
      'EXECCODE'      => '0000',
      'OPERATIONTYPE' => 'payment',
      'MESSAGE'       => 'Message a caractere informatif',
      'TRANSACTIONID' => 'AB12345678'
    })
    # Valid failure response
    assert @gateway.send(:response_is_valid?, {
      'EXECCODE'      => '4001',
      'OPERATIONTYPE' => 'payment',
      'MESSAGE'       => 'Message a caractere informatif'
    })
    # Invalid response (lacks EXECCODE)
    assert !@gateway.send(:response_is_valid?, {
      'OPERATIONTYPE' => 'payment',
      'MESSAGE'       => 'Message a caractere informatif',
      'TRANSACTIONID' => 'AB12345678'
    })
    # Invalid response (lacks OPERATIONTYPE)
    assert !@gateway.send(:response_is_valid?, {
      'EXECCODE'      => '0000',
      'MESSAGE'       => 'Message a caractere informatif',
      'TRANSACTIONID' => 'AB12345678'
    })
    # Invalid response (lacks MESSAGE)
    assert !@gateway.send(:response_is_valid?, {
      'EXECCODE'      => '0000',
      'OPERATIONTYPE' => 'payment',
      'TRANSACTIONID' => 'AB12345678'
    })
    # Invalid response (lacks TRANSACTIONID while EXECCODE indicates success)
    assert !@gateway.send(:response_is_valid?, {
      'EXECCODE'      => '0000',
      'MESSAGE'       => 'Message a caractere informatif',
      'OPERATIONTYPE' => 'payment'
    })
    # Invalid response (invalid EXECCODE)
    assert !@gateway.send(:response_is_valid?, {
      'EXECCODE'      => '000',
      'OPERATIONTYPE' => 'payment',
      'MESSAGE'       => 'Message a caractere informatif',
      'TRANSACTIONID' => 'AB12345678'
    })
    # Invalid response (invalid OPERATIONTYPE)
    assert !@gateway.send(:response_is_valid?, {
      'EXECCODE'      => '0000',
      'OPERATIONTYPE' => 'not_an_action',
      'MESSAGE'       => 'Message a caractere informatif',
      'TRANSACTIONID' => 'AB12345678'
    })
  end

  def test_response_is_success
    # Successful response
    assert @gateway.send(:response_is_success?, {
      'EXECCODE'      => '0000'
    })
    # Failure response
    assert !@gateway.send(:response_is_success?, {
      'EXECCODE'      => '4001'
    })
  end

  def test_be2bill_response_class
    # Response does require 3DSecure
    @gateway.expects(:ssl_post).returns(purchase_requires_3dsecure_response)
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of ActiveMerchant::Billing::Be2billResponse, response
    assert response.respond_to? :requires_3dsecure?
    assert response.send(:requires_3dsecure?)
    # Response does *not* require 3DSecure
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of ActiveMerchant::Billing::Be2billResponse, response
    assert response.respond_to? :requires_3dsecure?
    assert !response.send(:requires_3dsecure?)
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)

    assert_instance_of ActiveMerchant::Billing::Be2billResponse, response
    assert_success response
    assert response.test?
    assert_equal '0000', response.params['EXECCODE']
    assert_equal response.authorization, 'AB12345678'
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)

    assert_instance_of ActiveMerchant::Billing::Be2billResponse, response
    assert_failure response
    assert response.test?
    assert_match response.params['EXECCODE'], /^[1-9][0-9]{3}$/
  end

  private

  def successful_purchase_response
    '{"OPERATIONTYPE":"payment","TRANSACTIONID":"AB12345678","EXECCODE":"0000","MESSAGE":"The transaction has been accepted.","DESCRIPTOR":"Skiwallet"}'
  end

  def purchase_requires_3dsecure_response
    '{"OPERATIONTYPE":"payment","TRANSACTIONID":"AB12345678","EXECCODE":"0001","MESSAGE":"The transaction requires 3DSecure authentification.","DESCRIPTOR":"Skiwallet"}'
  end

  def failed_purchase_response
    '{"OPERATIONTYPE":"payment","TRANSACTIONID":"AB12345678","EXECCODE":"4001","MESSAGE":"The bank refused the transaction."}'
  end

end
