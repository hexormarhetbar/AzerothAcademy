-- Azeroth Academy - Duel of Wits wire protocol (pure Lua, no WoW API).
-- Message = "AA<version>~<TYPE>~field~field...". Fields are escaped so a
-- separator can never be injected. Messages longer than one addon message are
-- split into "AC" chunks and put back together on the other side. A small
-- token-bucket queue keeps us well under the client's addon-message limits.
local _, ns = ...

local DP = {}
ns.DuelProto = DP

DP.PREFIX = "AzAcadDuel"   -- addon message prefix (max 16 characters)
DP.VERSION = 2             -- bump on any incompatible change; peers compare it
-- v1.1 (protocol 2): language duels. The message format did not change, so a duel on a v0.10
-- subject is still sent as protocol 1 and v1.0 players can join it. A duel on a language
-- subject (World Tongues) is sent as protocol 2: a v1.0 client answers VER ("different addon
-- version") instead of joining a race it cannot build.
DP.MIN_VERSION = 1         -- oldest protocol we still read
DP.sendVersion = nil       -- set per message by the engine (nil = DP.VERSION)
DP.MAX = 250               -- WoW allows 255 bytes per addon message; keep slack
DP.CHUNK_DATA = 200        -- payload bytes per chunk (header fits in the rest)
DP.CHUNK_TIMEOUT = 20      -- seconds before a half-received message is dropped

local SEP = "~"

local function esc(v)
  v = tostring(v == nil and "" or v)
  return (v:gsub("%%", "%%25"):gsub("~", "%%7E"):gsub("|", "%%7C"):gsub("\n", "%%0A"))
end
local function unesc(v)
  return (v:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end
DP.Escape, DP.Unescape = esc, unesc

function DP.Encode(mtype, ...)
  local parts = { "AA" .. (DP.sendVersion or DP.VERSION), mtype }
  for i = 1, select("#", ...) do parts[#parts + 1] = esc((select(i, ...))) end
  return table.concat(parts, SEP)
end

-- Returns version (number), type, fields table. nil for anything that is not ours.
function DP.Decode(msg)
  if type(msg) ~= "string" or #msg > 4096 then return nil end
  local ver = msg:match("^AA(%d+)~")
  if not ver then return nil end
  local fields = {}
  for part in (msg .. SEP):gmatch("([^~]*)~") do fields[#fields + 1] = part end
  table.remove(fields, 1) -- version
  local mtype = table.remove(fields, 1)
  if not mtype or not mtype:match("^%u[%u%d]*$") then return nil end
  for i = 1, #fields do fields[i] = unesc(fields[i]) end
  return tonumber(ver), mtype, fields
end

------------------------------------------------------------------------
-- Chunking: "AC~<id>~<i>~<n>~<data>" (data is raw slice of the message)
------------------------------------------------------------------------
local chunkCounter = 0
function DP.Split(msg)
  if #msg <= DP.MAX then return { msg } end
  chunkCounter = chunkCounter % 9999 + 1
  local out, n = {}, math.ceil(#msg / DP.CHUNK_DATA)
  for i = 1, n do
    out[i] = "AC~" .. chunkCounter .. "~" .. i .. "~" .. n .. "~" .. msg:sub((i - 1) * DP.CHUNK_DATA + 1, i * DP.CHUNK_DATA)
  end
  return out
end

-- Reassembler. Feed every raw message; returns the complete message (or nil
-- while waiting for more pieces). Non-chunk messages pass straight through.
function DP.NewAssembler()
  local A = { pending = {} }
  function A:Feed(raw, sender, now)
    local id, i, n, data = raw:match("^AC~(%d+)~(%d+)~(%d+)~(.*)$")
    if not id then return raw end
    i, n = tonumber(i), tonumber(n)
    if n < 1 or n > 20 or i < 1 or i > n then return nil end
    local key = tostring(sender) .. ":" .. id
    local p = self.pending[key]
    if not p or p.n ~= n then
      p = { n = n, got = 0, parts = {}, at = now or 0 }
      self.pending[key] = p
    end
    if not p.parts[i] then p.parts[i], p.got = data, p.got + 1 end
    p.at = now or p.at
    if p.got < n then return nil end
    self.pending[key] = nil
    return table.concat(p.parts)
  end
  function A:Expire(now)
    for k, p in pairs(self.pending) do
      if (now or 0) - p.at > DP.CHUNK_TIMEOUT then self.pending[k] = nil end
    end
  end
  return A
end

------------------------------------------------------------------------
-- Throttle queue (ChatThrottleLib-style token bucket)
--   capacity: burst size, rate: messages per second refill.
--   Push(msg, channel, target, key): a pending item with the same key is
--   replaced (progress updates coalesce instead of piling up).
------------------------------------------------------------------------
function DP.NewQueue(capacity, rate)
  local Q = { items = {}, tokens = capacity or 8, capacity = capacity or 8, rate = rate or 1, last = nil, sent = 0 }
  function Q:Push(msg, channel, target, key)
    local pieces = DP.Split(msg)
    if #pieces > 1 then key = nil end -- chunked messages never coalesce
    if key then
      for _, it in ipairs(self.items) do
        if it.key == key then it.msg, it.channel, it.target = msg, channel, target; return end
      end
    end
    for _, piece in ipairs(pieces) do
      self.items[#self.items + 1] = { msg = piece, channel = channel, target = target, key = key }
    end
  end
  function Q:Flush(now, sendFn)
    if self.last then
      self.tokens = math.min(self.capacity, self.tokens + (now - self.last) * self.rate)
    end
    self.last = now
    while self.items[1] and self.tokens >= 1 do
      local it = table.remove(self.items, 1)
      self.tokens = self.tokens - 1
      self.sent = self.sent + 1
      sendFn(it.msg, it.channel, it.target)
    end
  end
  function Q:Size() return #self.items end
  function Q:Clear() self.items = {} end
  return Q
end
