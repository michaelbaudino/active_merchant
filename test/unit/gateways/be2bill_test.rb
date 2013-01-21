require 'test_helper'

class Be2billTest < Test::Unit::TestCase
  def setup
    @gateway = Be2billGateway.new(
                 :login => 'login',
                 :password => 'password'
               )

    @credit_card = credit_card
    @amount = 1000

    @options = {
      :order_id => 1,
      :address => address,
      :customer => 'Guest #42',
      :description => 'A ski pass from SkiWallet',
      :client_useragent => 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.11 (KHTML, like Gecko) Ubuntu Chromium/23.0.1271.97 Chrome/23.0.1271.97 Safari/537.11',
      :client_ip => '42.42.42.42',
      :client_email => 'georges.abitbol@alpine-lab.com'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)

    assert_instance_of ActiveMerchant::Billing::Response, response
    assert_success response
    assert response.test?
    assert_equal '0000', response.params['EXECCODE']
    assert_equal 'AB12345678', response.authorization
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)

    assert_instance_of ActiveMerchant::Billing::Response, response
    assert_failure response
    assert response.test?
    assert_match /^[1-9][0-9]{3}$/, response.params['EXECCODE']
  end

  private

  def successful_purchase_response
    '{"OPERATIONTYPE":"payment","TRANSACTIONID":"AB12345678","EXECCODE":"0000","MESSAGE":"The transaction has been accepted.","DESCRIPTOR":"Skiwallet"}'
  end

  def failed_purchase_response
    '{"OPERATIONTYPE":"payment","TRANSACTIONID":"AB12345678","EXECCODE":"4001","MESSAGE":"The bank refused the transaction."}'
  end

end
