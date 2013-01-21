module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class Be2billGateway < Gateway

      # Gateway global variables
      self.display_name = 'Be2Bill'
      self.homepage_url = 'http://www.be2bill.com/'
      self.supported_countries = ['FR']
      self.supported_cardtypes = [:visa, :master, :american_express]
      self.default_currency = :eur
      self.money_format = :cents
      self.test_url = 'https://secure-test.be2bill.com/front/service/rest/process.php'
      self.live_url = 'https://secure.be2bill.com/front/service/rest/process.php'
      API_VERSION = '2.0'

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def purchase(money, creditcard, options = {})
        params = {}
        add_amount(params, money)
        add_order(params, options)
        add_customer(params, options)
        add_description(params, options)
        add_creditcard(params, creditcard)
        commit(:payment, params)
      end

      def authorize(money, creditcard, options = {})
        # commit('authorize', ...)
      end

      def capture(money, authorization, options = {})
        # commit('capture', ...)
      end

      def refund(money, reference, options = {})
        # commit('refund', ...)
      end

      def credit(money, identification_or_credit_card, options = {})
        # commit('credit', ...)
      end

      private

      def add_amount(params, amount)
        params[:AMOUNT] = amount
      end

      def add_order(params, options)
        params[:ORDERID] = options[:order_id]
      end

      def add_customer(params, options)
        params[:CLIENTIDENT] = options[:customer]
        params[:CLIENTUSERAGENT] = options[:client_useragent] || 'Unknown'
        params[:CLIENTIP] = options[:client_ip] || 'Unknown'
        params[:CLIENTEMAIL] = options[:client_email] || 'unknown@nofuckingidea.com'
      end

      def add_description(params, options)
        params[:DESCRIPTION] = options[:description]
      end

      def add_creditcard(params, creditcard)
        params[:CARDCODE] = creditcard.number
        params[:CARDFULLNAME] = "#{creditcard.first_name || 'Anonymous'}#{creditcard.last_name || 'Anonymous'}"
        params[:CARDVALIDITYDATE] = "#{"%02d" % creditcard.month}-#{"%02d" % (creditcard.year % 100)}"
        params[:CARDCVV] = creditcard.verification_value
      end

      def be2bill_digest(params = {})
        clear_str = "#{@options[:password]}"
        params.sort.each do |key, value|
          clear_str << "#{key}=#{value}#{@options[:password]}"
        end
        Digest::SHA2.new(256) << clear_str
      end

      def post_data(action, params)
        {method: action, params: params}.to_query
      end

      def commit(action, params, options = {})
        params[:OPERATIONTYPE] = action
        params[:IDENTIFIER] = @options[:login]
        params[:VERSION] = API_VERSION
        params[:HASH] = be2bill_digest(params)
        url = test? ? self.test_url : self.live_url
        json_response = ssl_post(url, post_data(action, params))
        response = JSON.parse(json_response)
        if response_is_valid? response
          Response.new(response_is_success?(response), response['MESSAGE'], response, {
          :test          => ActiveMerchant::Billing::Base.mode == :test,
          :authorization => response['TRANSACTIONID']
          })
        else
          Response.new(false, 'Unprocessable response.')
        end
      end

      def response_is_valid?(response)
        response['EXECCODE'] =~ /[0-9]{4}/ &&
        ['payment', 'authorization', 'capture', 'refund', 'credit'].include?(response['OPERATIONTYPE']) &&
        response.has_key?('MESSAGE') &&
        (response['EXECCODE'][0] != '0' || response.has_key?('TRANSACTIONID'))
      end

      def response_is_success?(response)
        response['EXECCODE'] == '0000' || response['EXECCODE'] == '0001'
      end

    end
  end
end

