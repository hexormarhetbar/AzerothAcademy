-- World Tongues phrasebook: learn before you play. All ages may browse every lesson, with
-- a suggested Initiate/Adept/Magister order (Magister also suits an adult learner).
local _, ns = ...
local W, H, C, L = ns.W, ns.Hub, ns.Compat, ns.L
local D = ns.TonguesData
H.RegisterView("tonguesstudy", function(parent)
  local v = CreateFrame("Frame", nil, parent)
  v.hideGuide = true
  v.course, v.lesson, v.page = "ja", 1, 1
  local title = W.Text(v, 17, "", W.GOLD)
  title:SetPoint("TOPLEFT", 4, -2); title:SetWidth(420)
  W.SetFontFace(title, C.CourseFont(), 17)
  local back = W.Button(v, L.BACK, 90, 22, function() H.ShowView("forge") end)
  back:SetPoint("TOPRIGHT", 0, 0)
  local courseBtn = W.Button(v, "", 250, 24, function()
    local i = 1; for j, id in ipairs(D.order) do if id == v.course then i = j end end
    v.course, v.lesson, v.page = D.order[i % #D.order + 1], 1, 1
    ns.Progress.account.settings.tongues.course = v.course
    ns.Lessons.moduleId = "tongues_" .. v.course
    v:Render()
  end, 11)
  courseBtn:SetPoint("TOPLEFT", 4, -30)
  W.SetButtonFontFace(courseBtn, C.CourseFont(), 11)
  local track = W.Text(v, 10, "", W.ARCANE)
  track:SetPoint("TOPLEFT", 4, -62); track:SetWidth(540)
  local note = W.Text(v, 11, "", W.WHITE)
  note:SetPoint("TOPLEFT", 4, -85); note:SetWidth(540)
  W.SetFontFace(note, C.CourseFont(), 11)
  local lines, plays = {}, {}
  for i = 1, 8 do
    local t = W.Text(v, 13, "", W.WHITE)
    t:SetPoint("TOPLEFT", 6, -156 - (i - 1) * 29); t:SetWidth(535)
    W.SetFontFace(t, C.CourseFont(), 13)
    lines[i] = t
    -- v1.2: hear the entry (only when it has a clip and sound is on)
    local b = W.Button(v, L.WT_PLAY_SHORT, 50, 22, function(self)
      if self.clip and not C.PlayTongue(self.clip) then v:Render() end -- failed: hide what cannot play
    end, 11)
    b:SetPoint("TOPLEFT", 4, -152 - (i - 1) * 29)
    b:Hide()
    plays[i] = b
  end
  v.plays = plays
  local prev = W.Button(v, "<", 36, 24, function() v.page = v.page - 1; v:Render() end)
  prev:SetPoint("BOTTOMLEFT", 4, 42)
  local pageText = W.Text(v, 11, "", W.GRAY)
  pageText:SetPoint("LEFT", prev, "RIGHT", 8, 0); pageText:SetWidth(90)
  local nextBtn = W.Button(v, ">", 36, 24, function() v.page = v.page + 1; v:Render() end)
  nextBtn:SetPoint("LEFT", pageText, "RIGHT", 8, 0)
  local prevLesson = W.Button(v, L.WT_PREV_LESSON, 155, 24, function()
    v.lesson = math.max(1, v.lesson - 1); v.page = 1; v:Render()
  end, 11)
  prevLesson:SetPoint("BOTTOMLEFT", 4, 4)
  local nextLesson = W.Button(v, L.WT_NEXT_LESSON, 155, 24, function()
    v.lesson = math.min(#D.courses[v.course].lessons, v.lesson + 1); v.page = 1; v:Render()
  end, 11)
  nextLesson:SetPoint("LEFT", prevLesson, "RIGHT", 6, 0)
  local practice = W.Button(v, L.PRACTICE, 150, 24, function()
    local lesson = D.courses[v.course].lessons[v.lesson]
    local id = "wt_" .. v.course .. "_" .. lesson.id
    ns.Lessons.moduleId = "tongues_" .. v.course
    ns.Lessons.StartRound(id, ns.Mastery.CurrentTier(id))
  end, 12)
  practice:SetPoint("BOTTOMRIGHT", 0, 4)
  function v:Render()
    local course = D.courses[self.course] or D.courses.ja
    local lesson = course.lessons[self.lesson]
    local key = "WT_NODE_" .. self.course:upper() .. "_" .. lesson.id:upper()
    title:SetText(L[key]); courseBtn:SetText(course.name .. " >")
    track:SetText(string.format(L.WT_TRACK, L["BAND_" .. lesson.band:upper()], self.lesson, #course.lessons))
    local noteKey = self.course == "ja" and "WT_NOTES_JA" or "WT_NOTES_ES"
    if lesson.kind == "kana" then noteKey = "WT_NOTES_KANA" elseif lesson.kind == "kanji" then noteKey = "WT_NOTES_KANJI" end
    if lesson.kind == "sentences" then noteKey = "WT_H_SENTENCE" end
    note:SetText(L[noteKey])
    local pages = math.max(1, math.ceil(#lesson.entries / #lines))
    self.page = ns.Util.Clamp(self.page, 1, pages)
    pageText:SetText(string.format(L.PAGE_OF, self.page, pages))
    local TA = ns.TonguesAudio
    local audio = TA and TA.Available()
    local any = false
    for i, t in ipairs(lines) do
      local e = lesson.entries[(self.page - 1) * #lines + i]
      t:SetText(e and ns.Tongues.Explain(e) or "")
      local clip = audio and e and TA.Clip(self.course, e[1]) or nil
      plays[i].clip = clip
      if clip then plays[i]:Show(); any = true else plays[i]:Hide() end
    end
    for i, t in ipairs(lines) do
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", any and 60 or 6, -156 - (i - 1) * 29); t:SetWidth(any and 481 or 535)
    end
    if self.page == 1 then prev:Disable() else prev:Enable() end
    if self.page == pages then nextBtn:Disable() else nextBtn:Enable() end
    if self.lesson == 1 then prevLesson:Disable() else prevLesson:Enable() end
    if self.lesson == #course.lessons then nextLesson:Disable() else nextLesson:Enable() end
  end
  function v:OnShowView()
    local m = ns.Lessons.CurrentModule()
    self.course = m.course or ns.Progress.account.settings.tongues.course or "ja"
    self.lesson = math.min(self.lesson or 1, #D.courses[self.course].lessons)
    self:Render()
  end
  return v
end)
