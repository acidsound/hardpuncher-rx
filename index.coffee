$ = (e) -> document.getElementById e
Rx.Observable.fromEvent(document, 'DOMContentLoaded').subscribe ->
  console.log "PPOOOM"
  ### 1. 전투 기록 ###
  logSubject = new Rx.BehaviorSubject '적이 나타났다!'
  logSubject.subscribe (o) ->
    logArea = $('log')
    logArea.innerText = "#{o}\n#{logArea.innerText}"

  ### 2. 적 subject ###
  enemySubject = new Rx.Subject
  enemyHitAnim = (o) ->
    ### 피격 Animation ###
    effect =
      'hit': ->
        TweenMax.to $('enemy'), 0.05,
          top: '1rem'
          yoyo: true
          repeat: 3
      'CRITICAL!': ->
        TweenMax.to document.querySelector('.틀'), 0.05,
          css:
            scale: 1.3
            rotation: 5
          yoyo: true
          repeat: 3
    effect[o.lastAttack.action]()
    logSubject.next "#{o.lastAttack.action} 데미지\
      #{o.lastAttack.damage}! HP: #{o.hp}"

  # state-stores
  enemyState = Rx.Observable.of hp:200
  .merge enemySubject
  .scan (p, n)->
    Object.assign p,
      hp: p.hp-n.damage
      lastAttack: n
  .filter (o)-> o.lastAttack
  enemyState.subscribe (o)-> enemyHitAnim o

  ### 3. 주먹 subject ###
  punchSubject = new Rx.BehaviorSubject 'ready'
  punchSubject.filter (o)->o is 'ready'
  .subscribe -> # console.log 'ready'
  punchSubject.filter (o)->o is 'punch'
  .subscribe ->
    TweenLite.fromTo $('punch'), 0.3, left: '2rem',
      left: '76%'
      ease: Power4.easeIn
      onComplete: ->
        punchSubject.next 'crash'
  punchSubject.filter (o)->o is 'crash'
  .subscribe ->
    anim=
      step1: ->
        TweenMax.to $('punch'), 0.05,
          top: '1rem'
          yoyo: true
          repeat: 3
          onComplete: => @step2()
      step2: ->
        TweenLite.fromTo $('punch'), 0.05, left: '76%',
          left: '2rem'
          ease: Power4.easeIn
          onComplete: ->
            punchSubject.next 'ready'
    anim.step1()
    ### 적 힛트!! ###
    calcDamage = ->
      if (~~(~~(Math.random()*11)/10))<1
        action: 'hit'
        damage: 10
      else
        action: 'CRITICAL!'
        damage: 50
    enemySubject.next calcDamage()

  # 4. 주먹의 상태 - hit
  punchState = punchSubject.filter (o)->o is 'hitted'
  punchState.subscribe (o)->
    TweenMax.to $('stage'), 0.05,
      left: '0.5rem'
      yoyo: true
      repeat: 3
      onComplete: ->
        punchSubject.next 'ready'
  new Rx.Observable.of 2000
  .merge punchState.map (o)-> 100
  .scan (p, n)-> p - n
  .subscribe (o)->
    console.log "HP: #{o}"
    # 맞고 있다.

  ### 5. 공격 클릭 스트림 ###
  [
    'mousedown'
    'touchstart'
  ].map (v) ->
    clickStream = Rx.Observable.fromEvent $('fire'), v
    ### 중복 공격 방지. punchSubject의 마지막 상태가 ready(r) 일때만 filter 한다.
       punchSubject : r - p c r - p c r - p c r (r:ready, p: punch, c: crash)
       clickStream  : - c - c - c c - - c - - -
       sample       : - r - c - r p - - r - - - (take only punchSubject)
       filter ===r  : - r - - - r - - - r - - -
    ###
    checkReadyStream = punchSubject.sample clickStream
    .filter (o) -> o is 'ready'
    checkReadyStream.subscribe (o) ->
      punchSubject.next 'punch'

  # 6. 적 공격 2sec 마다 한번씩
  enemyAttackStream = Rx.Observable.interval 4000
  .subscribe (o)->
    punchSubject.next 'hitted'

# end of code