# encoding: utf-8
require 'test_helper'

class TicketArticlesControllerTest < ActionDispatch::IntegrationTest
  setup do

    # set accept header
    @headers = { 'ACCEPT' => 'application/json', 'CONTENT_TYPE' => 'application/json' }

    # create agent
    roles  = Role.where(name: %w(Admin Agent))
    groups = Group.all

    UserInfo.current_user_id = 1
    @admin = User.create_or_update(
      login: 'tickets-admin',
      firstname: 'Tickets',
      lastname: 'Admin',
      email: 'tickets-admin@example.com',
      password: 'adminpw',
      active: true,
      roles: roles,
      groups: groups,
    )

    # create agent
    roles = Role.where(name: 'Agent')
    @agent = User.create_or_update(
      login: 'tickets-agent@example.com',
      firstname: 'Tickets',
      lastname: 'Agent',
      email: 'tickets-agent@example.com',
      password: 'agentpw',
      active: true,
      roles: roles,
      groups: groups,
    )

    # create customer without org
    roles = Role.where(name: 'Customer')
    @customer_without_org = User.create_or_update(
      login: 'tickets-customer1@example.com',
      firstname: 'Tickets',
      lastname: 'Customer1',
      email: 'tickets-customer1@example.com',
      password: 'customer1pw',
      active: true,
      roles: roles,
    )

  end

  test '01.01 ticket create with agent and articles' do
    credentials = ActionController::HttpAuthentication::Basic.encode_credentials('tickets-agent@example.com', 'agentpw')

    params = {
      title: 'a new ticket #1',
      group: 'Users',
      customer_id: @customer_without_org.id,
      article: {
        body: 'some body',
      }
    }
    post '/api/v1/tickets', params.to_json, @headers.merge('Authorization' => credentials)
    assert_response(201)
    result = JSON.parse(@response.body)

    params = {
      ticket_id: result['id'],
      content_type: 'text/plain', # or text/html
      body: 'some body',
      type: 'note',
    }
    post '/api/v1/ticket_articles', params.to_json, @headers.merge('Authorization' => credentials)
    assert_response(201)
    result = JSON.parse(@response.body)
    assert_equal(Hash, result.class)
    assert_equal(nil, result['subject'])
    assert_equal('some body', result['body'])
    assert_equal('text/plain', result['content_type'])
    assert_equal(@agent.id, result['updated_by_id'])
    assert_equal(@agent.id, result['created_by_id'])

    ticket = Ticket.find(result['ticket_id'])
    assert_equal(2, ticket.articles.count)
    assert_equal(0, ticket.articles[0].attachments.count)
    assert_equal(0, ticket.articles[1].attachments.count)

    params = {
      ticket_id: result['ticket_id'],
      content_type: 'text/html', # or text/html
      body: 'some body <img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUA
AAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO
9TXL0Y4OHwAAAABJRU5ErkJggg==" alt="Red dot" />',
      type: 'note',
    }
    post '/api/v1/ticket_articles', params.to_json, @headers.merge('Authorization' => credentials)
    assert_response(201)
    result = JSON.parse(@response.body)
    assert_equal(Hash, result.class)
    assert_equal(nil, result['subject'])
    assert_no_match(/some body <img src="cid:/, result['body'])
    assert_match(%r{some body <img src="/api/v1/ticket_attachment/.}, result['body'])
    assert_equal('text/html', result['content_type'])
    assert_equal(@agent.id, result['updated_by_id'])
    assert_equal(@agent.id, result['created_by_id'])

    assert_equal(3, ticket.articles.count)
    assert_equal(0, ticket.articles[0].attachments.count)
    assert_equal(0, ticket.articles[1].attachments.count)
    assert_equal(1, ticket.articles[2].attachments.count)

    params = {
      ticket_id: result['ticket_id'],
      content_type: 'text/html', # or text/html
      body: 'some body',
      type: 'note',
      attachments: [
        'filename' => 'some_file.txt',
        'data' => 'dGVzdCAxMjM=',
        'mime-type' => 'text/plain',
      ],
    }
    post '/api/v1/ticket_articles', params.to_json, @headers.merge('Authorization' => credentials)
    assert_response(201)
    result = JSON.parse(@response.body)
    assert_equal(Hash, result.class)
    assert_equal(nil, result['subject'])
    assert_equal('some body', result['body'])
    assert_equal('text/html', result['content_type'])
    assert_equal(@agent.id, result['updated_by_id'])
    assert_equal(@agent.id, result['created_by_id'])

    assert_equal(4, ticket.articles.count)
    assert_equal(0, ticket.articles[0].attachments.count)
    assert_equal(0, ticket.articles[1].attachments.count)
    assert_equal(1, ticket.articles[2].attachments.count)
    assert_equal(1, ticket.articles[3].attachments.count)

    get "/api/v1/ticket_articles/#{result['id']}?expand=true", {}.to_json, @headers.merge('Authorization' => credentials)
    assert_response(200)
    result = JSON.parse(@response.body)
    assert_equal(Hash, result.class)
    assert_equal(1, result['attachments'].count)
  end

  test '02.01 ticket create with customer and articles' do
    credentials = ActionController::HttpAuthentication::Basic.encode_credentials('tickets-customer1@example.com', 'customer1pw')

    params = {
      title: 'a new ticket #2',
      group: 'Users',
      article: {
        body: 'some body',
      }
    }
    post '/api/v1/tickets', params.to_json, @headers.merge('Authorization' => credentials)
    assert_response(201)
    result = JSON.parse(@response.body)

    params = {
      ticket_id: result['id'],
      content_type: 'text/plain', # or text/html
      body: 'some body',
      type: 'note',
    }
    post '/api/v1/ticket_articles', params.to_json, @headers.merge('Authorization' => credentials)
    assert_response(201)
    result = JSON.parse(@response.body)
    assert_equal(Hash, result.class)
    assert_equal(nil, result['subject'])
    assert_equal('some body', result['body'])
    assert_equal('text/plain', result['content_type'])
    assert_equal(@customer_without_org.id, result['updated_by_id'])
    assert_equal(@customer_without_org.id, result['created_by_id'])

    ticket = Ticket.find(result['ticket_id'])
    assert_equal(2, ticket.articles.count)
    assert_equal('Customer', ticket.articles[1].sender.name)
    assert_equal(0, ticket.articles[0].attachments.count)
    assert_equal(0, ticket.articles[1].attachments.count)

    params = {
      ticket_id: result['ticket_id'],
      content_type: 'text/plain', # or text/html
      body: 'some body',
      sender: 'Agent',
      type: 'note',
    }
    post '/api/v1/ticket_articles', params.to_json, @headers.merge('Authorization' => credentials)
    assert_response(201)
    result = JSON.parse(@response.body)
    assert_equal(Hash, result.class)
    assert_equal(nil, result['subject'])
    assert_equal('some body', result['body'])
    assert_equal('text/plain', result['content_type'])
    assert_equal(@customer_without_org.id, result['updated_by_id'])
    assert_equal(@customer_without_org.id, result['created_by_id'])

    ticket = Ticket.find(result['ticket_id'])
    assert_equal(3, ticket.articles.count)
    assert_equal('Customer', ticket.articles[2].sender.name)
    assert_equal(false, ticket.articles[2].internal)
    assert_equal(0, ticket.articles[0].attachments.count)
    assert_equal(0, ticket.articles[1].attachments.count)
    assert_equal(0, ticket.articles[2].attachments.count)

    params = {
      ticket_id: result['ticket_id'],
      content_type: 'text/plain', # or text/html
      body: 'some body 2',
      sender: 'Agent',
      type: 'note',
      internal: true,
    }
    post '/api/v1/ticket_articles', params.to_json, @headers.merge('Authorization' => credentials)
    assert_response(201)
    result = JSON.parse(@response.body)
    assert_equal(Hash, result.class)
    assert_equal(nil, result['subject'])
    assert_equal('some body 2', result['body'])
    assert_equal('text/plain', result['content_type'])
    assert_equal(@customer_without_org.id, result['updated_by_id'])
    assert_equal(@customer_without_org.id, result['created_by_id'])

    ticket = Ticket.find(result['ticket_id'])
    assert_equal(4, ticket.articles.count)
    assert_equal('Customer', ticket.articles[3].sender.name)
    assert_equal(false, ticket.articles[3].internal)
    assert_equal(0, ticket.articles[0].attachments.count)
    assert_equal(0, ticket.articles[1].attachments.count)
    assert_equal(0, ticket.articles[2].attachments.count)
    assert_equal(0, ticket.articles[3].attachments.count)

    # add internal article
    article = Ticket::Article.create(
      ticket_id: ticket.id,
      from: 'some_sender@example.com',
      to: 'some_recipient@example.com',
      subject: 'some subject',
      message_id: 'some@id',
      body: 'some message 123',
      internal: true,
      sender: Ticket::Article::Sender.find_by(name: 'Agent'),
      type: Ticket::Article::Type.find_by(name: 'note'),
      updated_by_id: 1,
      created_by_id: 1,
    )
    assert_equal(5, ticket.articles.count)
    assert_equal('Agent', ticket.articles[4].sender.name)
    assert_equal(1, ticket.articles[4].updated_by_id)
    assert_equal(1, ticket.articles[4].created_by_id)
    assert_equal(0, ticket.articles[0].attachments.count)
    assert_equal(0, ticket.articles[1].attachments.count)
    assert_equal(0, ticket.articles[2].attachments.count)
    assert_equal(0, ticket.articles[3].attachments.count)
    assert_equal(0, ticket.articles[4].attachments.count)

    get "/api/v1/ticket_articles/#{article.id}", {}.to_json, @headers.merge('Authorization' => credentials)
    assert_response(401)
    result = JSON.parse(@response.body)
    assert_equal(Hash, result.class)
    assert_equal('Not authorized', result['error'])

    put "/api/v1/ticket_articles/#{article.id}", { internal: false }.to_json, @headers.merge('Authorization' => credentials)
    assert_response(401)
    result = JSON.parse(@response.body)
    assert_equal(Hash, result.class)
    assert_equal('Not authorized', result['error'])

  end

end