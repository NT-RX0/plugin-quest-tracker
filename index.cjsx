{ROOT, EXROOT} = global
{ROOT, layout, _, $, $$, React, ReactBootstrap} = window
{Label, OverlayTrigger, Tooltip} = ReactBootstrap

fs = require 'fs-extra'
path = require 'path'
CSON = require 'cson'

{log, warn, error} = require(path.join(ROOT, 'lib', 'utils'))
questDataPath = path.join(EXROOT, 'questdata.cson')

submarines = [530, 531, 532, 533, 534, 535, 570, 571, 572]
aircraftcarriers = [510, 512, 523, 525, 528, 560, 565, 579]
supplyships = [558, 526, 513]

trackpool = [
  #daily
  201, 216, 210, 218, 226, 230, 211, 212, 303, 304, 402, 403, 503, 504, 605, 606, 607, 608, 609, 619, 702,
  #weekly
  214, 220, 213, 221, 228, 229, 241, 242, 243, 261, 302, 404, 410, 411, 613, 703
]

CODEA = 214

# TODO: merge quest requirement with quest.cson
getTargetById = (id) ->
  switch id
    # daily
    when 201
      return 1
    when 216
      return 1
    when 210
      return 10
    when 218
      return 3
    when 226
      return 5
    when 230
      return 6
    when 211
      return 3
    when 212
      return 5
    when 303
      return 3
    when 304
      return 5
    when 402
      return 3
    when 403
      return 10
    when 503
      return 5
    when 504
      return 15
    when 605
      return 1
    when 606
      return 1
    when 607
      return 3
    when 608
      return 3
    when 609
      return 2
    when 619
      return 1
    when 702
      return 2
    # weekly
    when 214
      return 6 + 12 + 24 + 36
    when 220
      return 20
    when 213
      return 20
    when 221
      return 50
    when 228
      return 15
    when 229
      return 12
    when 241
      return 5
    when 242
      return 1
    when 243
      return 2
    when 261
      return 3
    when 302
      return 20
    when 404
      return 30
    when 410
      return 1
    when 411
      return 6
    when 613
      return 24
    when 703
      return 15
    # monthly
    # when 249
    #   return 1
    # when 256
    #   return 3
    # when 257
    #   return 1
    # when 259
    #   return 1
    # when 265
    #   return 1
    # when 266
    #   return 1
    else
      return 1

getProgressById = (id, track) ->
  if id not in trackpool
    return 0
  idx = _.findIndex track, (t) ->
    t.id == id
  if idx == -1
    return 0
  else
    return track[idx].progress

setProgressByTask = (task, progress, track) ->
  if task.id not in trackpool
    return
  idx = _.findIndex track, (t) ->
    t.id == task.id
  if idx != -1
    track[idx] =
      progress: progress  # save progress as digit
      id:       task.id
      name:     task.name
      content:  task.content
      category: task.category
      type:     task.type
  else
    newTask = Object.clone(emptyTask)
    newTask =
      progress: progress  # save progress as digit
      id:       task.id
      name:     task.name
      content:  task.content
      category: task.category
      type:     task.type
    track.push newTask

getCategoryById = (id) ->
  cat = Math.floor(id / 100)

saveTracker = (track) ->
  try
    fs.writeFileSync questDataPath, CSON.stringify(track)
  catch e
    warn e

readTracker = ->
  try
    fs.accessSync questDataPath, fs.R_OK | fs.W_OK
    track = CSON.parseCSONFile questDataPath
  catch e
    warn e
  return track

emptyTask =
  name: '未接受'
  id: 100000
  content: '...'
  progress: ''
  category: 0
  type: 0

module.exports =
  name: 'QuestTracker'
  priority: 15
  author: <span><a key={0} href="https://github.com/PHELiOX">Artoria</a></span>
  displayName: <span><FontAwesome key={0} name='check-circle-o' /> 任务进度</span>
  description: '跟踪激活中的任务完成情况'
  show: true
  version: '0.1.0'
  reactClass: React.createClass
    track: []
    memberId: 0
    mapArea: 0
    mapInfo: 0
    isBoss: false
    rank: ""
    tasks: [Object.clone(emptyTask), Object.clone(emptyTask), Object.clone(emptyTask),
            Object.clone(emptyTask), Object.clone(emptyTask), Object.clone(emptyTask)]
    getInitialState: ->
      percent: [0, 0, 0, 0, 0, 0]
      progress: [0, 0, 0, 0, 0, 0]
      target: [1, 1, 1, 1, 1, 1]
      codeA: [0, 0, 0, 0]       # fight, boss fight, S, boss S
      nowHp: null
      enemyId: null
    handleResponse: (e) ->
      flag = false
      {method, path, body, postBody} = e.detail
      newPercent = [0, 0, 0, 0, 0, 0]
      newProgress = [0, 0, 0, 0, 0, 0]
      newTarget = [1, 1, 1, 1, 1, 1]
      switch path
        # check id to store progress separately
        when '/kcsapi/api_get_member/basic'
          @memberId = parseInt(body.api_member_id)
        when '/kcsapi/api_req_quest/clearitemget'
          if postBody.api_quest_id?
            complete = parseInt(postBody.api_quest_id)
            @track = @track.filter (t) -> t.id != complete
            idx = _.findIndex @tasks, (t) -> t.id == complete
            return if idx == -1
            tasks[idx] = Object.clone(emptyTask)
        else
          for task, i in @tasks
            continue if !task? or task.id is 100000
            # calibrate current progress
            progress = @state.progress[i]
            target = @state.target[i]
            # id 分类
            cat = getCategoryById task.id
            switch cat
              when 2
                switch path
                  # possible bug when refresh game
                  when '/kcsapi/api_req_map/start'
                    @mapArea = body.api_maparea_id
                    @mapInfo = body.api_mapinfo_no
                    @isBoss = false
                  when '/kcsapi/api_req_map/next'
                    if body.api_bosscell_no == body.api_no
                      @isBoss = true
                  when '/kcsapi/api_req_sortie/battleresult'
                    @rank = body.api_win_rank

              when 3
                switch path
                  when '/kcsapi/api_req_practice/battle_result'
                    switch task.id
                      when 303
                        progress += 1
                      when 304, 302
                        switch body.api_win_rank
                          when "A", "S", "B"
                            progress += 1
                            flag = true
              when 4
                switch path
                  when '/kcsapi/api_req_mission/result'
                    switch task.id
                      when 410, 411
                        if body.api_clear_result > 0
                          if body.api_quest_name is "東京急行" or body.api_quest_name is "東京急行(弐)"
                            progress += 1
                            flag = true
                      when 402, 403, 404
                        if body.api_clear_result > 0
                          progress += 1
                          flag = true
              when 5
                switch path
                  when '/kcsapi/api_req_nyukyo/start'
                    switch task.id
                      when 503
                        progress += 1
                        flag = true
                  when'/kcsapi/api_req_hokyu/charge'
                    switch task.id
                      when 504
                        progress += 1
                        flag = true
              when 6
                switch path
                  when '/kcsapi/api_req_kousyou/createitem'
                    if task.id == 605 || 607
                      progress += 1
                      flag = true
                  when '/kcsapi/api_req_kousyou/createship'
                    if task.id == 606 || 608
                      progress += 1
                      flag = true
                  when '/kcsapi/api_req_kousyou/destroyitem2'
                    if task.id == 613
                      progress += 1
                      flag = true
                  when '/kcsapi/api_req_kousyou/destroyship'
                    if task.id == 609
                      progress += 1
                      flag = true
                  when '/kcsapi/api_req_kousyou/remodel_slot'
                    if task.id == 619
                      progress += 1
                      flag = true
              when 7
                switch path
                  when '/kcsapi/api_req_kaisou/powerup'
                    switch task.id
                      when 702, 703
                        if body.api_success == 1
                          progress += 1
                          flag = true
            newProgress[i] = progress = if progress > target then target else progress
            newTarget[i] = target
            newPercent[i] = Math.floor(progress / target * 100)
            # Save progress by memberId and questId
            setProgressByTask task, progress, @track
            saveTracker @track
          if flag
            @setState
              progress: newProgress
              target: newTarget
              percent: newPercent
            event = new CustomEvent 'task.update',
              bubbles: true
              cancelable: true
              detail:
                codeA: @state.codeA
                percent: newPercent
                progress: newProgress
                target: newTarget
            window.dispatchEvent event
    handleBattleResult: (e) ->
      flag = false
      {isCombined, nowHp, enemyId, rank} = e.detail
      newPercent = [0, 0, 0, 0, 0, 0]
      newProgress = [0, 0, 0, 0, 0, 0]
      newTarget = [1, 1, 1, 1, 1, 1]
      codeA = [0, 0, 0, 0]
      if not isCombined
        nowHp = nowHp[5..11]   # add 0 slot
        @rank = rank
      for task, i in @tasks
        continue if !task? or task.id is 100000
        progress = @state.progress[i]
        target = @state.target[i]
        switch task.id
          # fight
          when 216, 210
            progress += 1
            flag = true
          # All win
          when 201
            switch @rank
              when "A", "S", "B"
                progress += 1
                flag = true
          # Supply ship
          when 218, 212, 213, 221
            for id, j in enemyId
              if id in supplyships and nowHp[j] is 0
                progress += 1
                flag = true
          # Aircraft Carrier
          when 211, 220
            for id, j in enemyId
              if id in aircraftcarriers and nowHp[j] is 0
                progress += 1
                flag = true
            break
          # Submarines
          when 230, 228
            for id, j in enemyId
              if id in submarines and nowHp[j] is 0
                progress += 1
                flag = true
            break
          # southwest
          when 226
            if @mapArea == 2
              if @isBoss
                switch @rank
                  when "A", "S", "B"
                    progress += 1
                    flag = true
          # west
          when 229
            if @mapArea == 4
              if @isBoss
                switch @rank
                  when "A", "S", "B"
                    progress += 1
                    flag = true
          # west 4-4
          when 242
            if @mapArea == 4 and @mapInfo == 4
              if @isBoss
                switch @rank
                  when "A", "S", "B"
                    progress += 1
                    flag = true
          # north 3-3...3-5
          when 241
            if @mapArea == 3 and @mapInfo > 2
              if @isBoss
                switch @rank
                  when "A", "S", "B"
                    progress += 1
                    flag = true
          # south 5-2
          when 243
            if @mapArea == 5 and @mapInfo == 2
              if @isBoss
                switch @rank
                  when "A", "S", "B"
                    progress += 1
                    flag = true
          # near 1-5
          when 261
            if @mapArea == 1 and @mapInfo == 5
              if @isBoss
                switch @rank
                  when "A", "S", "B"
                    progress += 1
                    flag = true
          # Code A # fight, boss fight, S, boss S
          when 214
            codeA[0] += 1
            progress += 1
            flag = true
            if @isBoss
              codeA[1] += 1
              progress += 1
              flag = true
            if @rank == "S"
              codeA[2] += 1
              progress += 1
              flag = true
            if @isBoss and @rank == "S"
              codeA[3] += 1
              progress += 1
              flag = true
        newProgress[i] = progress = if progress > target then target else progress
        newTarget[i] = target
        newPercent[i] = Math.floor(progress / target * 100)
        # Save progress by memberId and questId
        if task.id == CODEA
          setProgressByTask task, codeA, @track
        else
          setProgressByTask task, progress, @track
        saveTracker @track
      if flag
        @setState
          codeA: codeA
          progress: newProgress
          target: newTarget
          percent: newPercent
        event = new CustomEvent 'task.update',
          bubbles: true
          cancelable: true
          detail:
            codeA: codeA
            percent: newPercent
            progress: newProgress
            target: newTarget
        window.dispatchEvent event
    handleTaskDidChange: (e) ->
      {tasks} = e.detail
      newPercent = [0, 0, 0, 0, 0, 0]
      newProgress = [0, 0, 0, 0, 0, 0]
      newTarget = [1, 1, 1, 1, 1, 1]
      # Save Data
      for task, i in @tasks
        continue unless task?
        if task.id == CODEA
          setProgressByTask task, @state.codeA, @track
        else
          setProgressByTask task, @state.progress[i], @track
      # lower the frequency saving settings to increase performance
      @tracks = _.sortBy @tracks, (e) -> e.id
      saveTracker @track
      # refresh quests
      for task, i in tasks
        if task.id == CODEA
          codeA = getProgressById task.id, @track
          progress = codeA.reduce (a, b) -> a + b
        else
          progress = getProgressById task.id, @track
        target = getTargetById task.id
        percent = Math.floor(progress / target * 100)
        actual = 0
        if task.progress == '达成'
          actual = 100
        else if task.progress == '50%'
          actual = 50
        else if task.progress == '80%'
          actual = 80
        if percent < actual
          progress = Math.ceil(actual / 100 * target)
        newProgress[i] = progress
        newTarget[i] = target
        newPercent[i] = percent = Math.floor(progress / target * 100)
      @tasks = Object.clone tasks
      @setState
        codeA: codeA
        progress: newProgress
        target: newTarget
        percent: newPercent
      # notify shipview
      event = new CustomEvent 'task.update',
        bubbles: true
        cancelable: true
        detail:
          codeA: codeA
          percent: newPercent
          progress: newProgress
          target: newTarget
      window.dispatchEvent event
    componentWillMount: ->
      # Read saved config
      track = readTracker()
      if not Array.isArray(track)
        warn "no quest track id #{@memberId}"
        track = []
      @track = Object.clone(track)
      idx = _.findIndex @track, (t) -> t.id == CODEA
      if idx != -1
        codeA = Object.clone(@track[idx])
        @track[idx].progress = codeA.reduce (a, b) -> a + b
      setState:
        codeA: codeA
    componentDidMount: ->
      window.addEventListener "task.change", @handleTaskDidChange
      window.addEventListener "battle.result", @handleBattleResult
      window.addEventListener "game.response", @handleResponse
      # window.addEventListener "window.beforeclose", @saveTracker
    componentWillUnmount: ->
      window.removeEventListener "task.change", @handleTaskDidChange
      window.removeEventListener "battle.result", @handleBattleResult
      window.removeEventListener "game.response", @handleResponse
      # window.removeEventListener "window.beforeclose", @saveTracker
    render: ->
      <div/>
