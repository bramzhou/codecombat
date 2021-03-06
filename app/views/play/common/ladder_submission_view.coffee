CocoView = require 'views/kinds/CocoView'
template = require 'templates/play/common/ladder_submission'

module.exports = class LadderSubmissionView extends CocoView
  class: "ladder-submission-view"
  template: template

  events:
    'click .rank-button': 'rankSession'

  constructor: (options) ->
    super options
    @session = options.session
    @level = options.level

  getRenderData: ->
    ctx = super()
    ctx.readyToRank = @session?.readyToRank()
    ctx.isRanking = @ession?.get('isRanking')
    ctx
      
  afterRender: ->
    super()
    return unless @supermodel.finished()
    @rankButton = @$el.find('.rank-button')
    @updateButton()

  updateButton: ->
    rankingState = 'unavailable'
    if @session?.readyToRank()
      rankingState = 'rank'
    else if @session?.get 'isRanking'
      rankingState = 'ranking'
    @setRankingButtonText rankingState

  setRankingButtonText: (spanClass) ->
    @rankButton.find('span').addClass('hidden')
    @rankButton.find(".#{spanClass}").removeClass('hidden')
    @rankButton.toggleClass 'disabled', spanClass isnt 'rank'

  rankSession: (e) ->
    return unless @session.readyToRank()
    @setRankingButtonText 'submitting'
    success = =>
      @setRankingButtonText 'submitted' unless @destroyed
      Backbone.Mediator.publish 'ladder:game-submitted', session: @session, level: @level
    failure = (jqxhr, textStatus, errorThrown) =>
      console.log jqxhr.responseText
      @setRankingButtonText 'failed' unless @destroyed
    transpiledCode = @transpileSession()

    ajaxData =
      session: @session.id
      levelID: @level.id
      originalLevelID: @level.get('original')
      levelMajorVersion: @level.get('version').major
      transpiledCode: transpiledCode

    $.ajax '/queue/scoring', {
      type: 'POST'
      data: ajaxData
      success: success
      error: failure
    }

  transpileSession: ->
    submittedCode = @session.get('code')
    transpiledCode = {}
    for thang, spells of submittedCode
      transpiledCode[thang] = {}
      for spellID, spell of spells
        unless _.contains(@session.get('teamSpells')[@session.get('team')], thang + "/" + spellID) then continue
        #DRY this
        aetherOptions =
          problems: {}
          language: "javascript"
          functionName: spellID
          functionParameters: []
          yieldConditionally: spellID is "plan"
          globals: ['Vector', '_']
          protectAPI: true
          includeFlow: false
        if spellID is "hear" then aetherOptions["functionParameters"] = ["speaker","message","data"]

        aether = new Aether aetherOptions
        transpiledCode[thang][spellID] = aether.transpile spell
    transpiledCode

