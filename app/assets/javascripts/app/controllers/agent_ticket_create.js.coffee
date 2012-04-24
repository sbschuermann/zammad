$ = jQuery.sub()

class Index extends App.Controller
  events:
    'click .customer_new': 'user_new'
    'submit form': 'submit',
    'click .submit': 'submit',
    'click .cancel': 'cancel',

  constructor: ->
    super

    # check authentication
    return if !@authenticate()
    
    # set title
    @title 'New Ticket'
#    @render()
    @fetch()
    @navupdate '#ticket_create'

    @edit_form = undefined
    
  fetch: () ->
    # get data
    @ajax = new App.Ajax
    @ajax.ajax(
      type:  'GET',
      url:   '/ticket_create',
      data:  {
#        view: @view
      }
      processData: true,
      success: (data, status, xhr) =>
        
        # get edit form attributes
        @edit_form = data.edit_form

        # load user collection
        @loadCollection( type: 'User', data: data.users )

        # render page
        @render()
    )

  render: ->
    
    configure_attributes = [
      { name: 'customer_id',        display: 'From',     tag: 'autocompletion', type: 'text', limit: 100, null: false, relation: 'User', class: 'span7', autocapitalize: false, help: 'Select the customer of the Ticket or create one.', link: '<a href="" class="customer_new">&raquo;</a>', callback: @userInfo },
      { name: 'group_id',           display: 'Group',    tag: 'select',   multiple: false, null: false, filter: @edit_form, nulloption: true, relation: 'Group', class: 'span7',  },
      { name: 'owner_id',           display: 'Owner',    tag: 'select',   multiple: false, null: true, filter: @edit_form, nulloption: true, relation: 'User', class: 'span7',  },
      { name: 'subject',            display: 'Subject',  tag: 'input',    type: 'text', limit: 100, null: false, class: 'span7',  },
      { name: 'body',               display: 'Text',     tag: 'textarea', rows: 6,      limit: 100, null: false, class: 'span7',  },
      { name: 'ticket_state_id',    display: 'State',    tag: 'select',   multiple: false, null: false, filter: @edit_form, relation: 'TicketState', default: 'new', class: 'medium' },
      { name: 'ticket_priority_id', display: 'Priority', tag: 'select',   multiple: false, null: false, filter: @edit_form, relation: 'TicketPriority', default: '2 normal', class: 'medium' },
    ]
    @html App.view('agent_ticket_create')(
      head: 'New Ticket',
      form: @formGen( model: { configure_attributes: configure_attributes, className: 'create' } ),
    )
    
  user_new: (e) =>
    e.preventDefault()
    new UserNew()

  cancel: ->
    @render()
    
  submit: (e) ->
    e.preventDefault()
        
    # get params
    params = @formParam(e.target)

    # fillup params
    if !params.title
      params.title = params.subject

    # create ticket
    object = new App.Ticket
    @log 'updateAttributes', params
    
    # find sender_id
    sender = App.TicketArticleSender.findByAttribute("name", "Customer")
    type   = App.TicketArticleType.findByAttribute("name", "phone")
    if params.group_id
      group  = App.Group.find(params.group_id)

    # create article
    params['article'] = {
      from:                     params.customer_id_autocompletion,
      to:                       (group && group.name) || '',
      subject:                  params.subject,
      body:                     params.body,
      ticket_article_type_id:   type.id,
      ticket_article_sender_id: sender.id,
      created_by_id:            params.customer_id,
    }
#          console.log('params', params)
    
    object.load(params)

    # validate form
    errors = object.validate()
    
    # show errors in form
    if errors
      @log 'error new', errors
      @validateForm( form: e.target, errors: errors )
      
    # save ticket, create article
    else 

      # disable form
      @formDisable(e)

      object.save(
        success: (r) =>

          # notify UI
          @notify
            type:    'success',
            msg:     "Ticket <a href=\"#ticket/zoom/#{r.id}\">#{r.number}</a> created!",
            timeout: 12000,
      
          # create new create screen
          @render()
          
          # scroll to top
          @scrollTo()

        error: =>
          @log 'save failed!'
      )


class UserNew extends App.ControllerModal
  constructor: ->
    super
    @render()

  render: ->

    @html App.view('agent_user_create')(
      head: 'New User',
      form: @formGen( model: App.User, required: 'quick' ),
    )
    @modalShow()
    
  submit: (e) ->
    @log 'submit'
    e.preventDefault()
    params = @formParam(e.target)
    
    # if no login is given, use emails as fallback
    if !params.login && params.email
      params.login = params.email
      
    user = new App.User
    
    # find role_id
    role = App.Role.findByAttribute("name", "Customer")
    params.role_ids = role.id
    @log 'updateAttributes', params
    user.load(params)

    errors = user.validate()
    if errors
      @log 'error new', errors
      @validateForm( form: e.target, errors: errors )
      return

    # save user
    user.save(
      success: (r) =>
        @modalHide()
        $('#create_customer_id').val(r.id)
        $('#create_customer_id_autocompletion').val(r.firstname)

        # start customer info controller
        @userInfo( user_id: r.id )
      error: =>
        @modalHide()
    )

Config.Routes['ticket_create'] = Index