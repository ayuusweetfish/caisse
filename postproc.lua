local function css(s)
  return s:gsub('{[^{}]*}', function (block)
    local logical = {
      size = {}, minsize = {}, maxsize = {},
      inset = {},
      border = {},
      margin = {},
      padding = {},
    }
    local function set(table, side, value)
      if side == 'block-start' then table[1] = value
      elseif side == 'block-end' then table[3] = value
      elseif side == 'inline-start' then table[4] = value
      elseif side == 'inline-end' then table[2] = value
      elseif side == 'block' or side == 'inline' then
        local v1, v2
        v1 = value:match('^(%g+%b())') or value:match('^(%g+)')
        v2 = value:match('(%g+%b())$') or value:match('(%g+)$')
        if side == 'block' then table[1], table[3] = v1, v2
        else table[4], table[2] = v1, v2 end
      else return false end
      return true
    end
    local concat = table.concat
    local function serialize(rules, table, ...)
      local count = (table[1] and 1 or 0) + (table[2] and 1 or 0) +
        (table[3] and 1 or 0) + (table[4] and 1 or 0)
      if count == 0 then return end
      local n = select('#', ...)
      if n >= 2 then
        -- Separate names
        for i = 1, n do if table[i] then
          rules[#rules + 1] = select(i, ...) .. ': ' .. table[i] .. ';'
        end end
      else
        -- Shorthands
        local name = select(1, ...)
        local dirs = {'top', 'right', 'bottom', 'left'}
        if count < 4 then
          -- Trivial dump
          for i = 1, 4 do if table[i] then
            rules[#rules + 1] = name .. '-' .. dirs[i] .. ': ' .. table[i] .. ';'
          end end
        else
          if table[4] == table[2] then
            table[4] = nil
            if table[3] == table[1] then
              table[3] = nil
              if table[2] == table[1] then table[2] = nil end
            end
          end
          rules[#rules + 1] = name .. ': ' .. concat(table, ' ') .. ';'
        end
      end
    end
    local remains = {}
    for k, v in block:gmatch('(%g+):%s*([^;]+);') do
      if not (
           (k:sub(-5) == '-size' and (
             set(logical.size, k:sub(1, -6), v)) or
             (k:sub(1, 4) == 'min-' and set(logical.minsize, k:sub(5, -6), v)) or
             (k:sub(1, 4) == 'max-' and set(logical.maxsize, k:sub(5, -6), v))
           )
        or (k:sub(1, 6) == 'inset-' and set(logical.inset, k:sub(7), v))
        or (k:sub(1, 7) == 'border-' and set(logical.border, k:sub(8), v))
        or (k:sub(1, 7) == 'margin-' and set(logical.margin, k:sub(8), v))
        or (k:sub(1, 8) == 'padding-' and set(logical.padding, k:sub(9), v))
      ) then
        v = (v == 'inline-end' and 'right'
          or (v == 'inline-start' and 'left') or v)
        remains[#remains + 1] = k .. ': ' .. v .. ';'
        -- Grid for IE11
        if k == 'display' and v == 'grid' then
          remains[#remains + 1] = 'display: -ms-grid;'
        end
        if k == 'grid-template-columns' then
          remains[#remains + 1] = '-ms-grid-columns: ' .. v .. ';'
        end
        if k == 'grid-row' or k == 'grid-column' then
          local start, span = v:match('(%d+) / span (%d+)')
          if start then
            remains[#remains + 1] = '-ms-' .. k .. ': ' .. start .. ';'
            remains[#remains + 1] = '-ms-' .. k .. '-span: ' .. span .. ';'
          else
            remains[#remains + 1] = '-ms-' .. k .. ': ' .. v .. ';'
          end
        end
      end
    end
    serialize(remains, logical.size, 'height', 'width')
    serialize(remains, logical.minsize, 'min-height', 'min-width')
    serialize(remains, logical.maxsize, 'max-height', 'max-width')
    serialize(remains, logical.inset, 'top', 'right', 'bottom', 'left')
    serialize(remains, logical.margin, 'margin')
    serialize(remains, logical.padding, 'padding')
    local init = block:match('^({%s+)')
    local fin = block:match('(%s+})$')
    return init .. table.concat(remains, init:sub(2)) .. fin
  end)
end

local function html(s)
  local cur = 1
  local ret = {}
  local styles = {}
  local firststylestart = nil
  while cur <= #s do
    local pos1s, pos1e = s:match('()<style>()', cur)
    if not pos1s then break end
    local pos2s, pos2e = s:match('()</style>()', pos1e)
    ret[#ret + 1] = s:sub(cur, pos1s - 1)
    styles[#styles + 1] = s:sub(pos1e, pos2s - 1)
    if not firststylestart then firststylestart = #ret + 1 end
    cur = pos2e
  end
  ret[#ret + 1] = s:sub(cur)
  if firststylestart then
    table.insert(ret, firststylestart,
      '<style>' .. css(table.concat(styles)) .. '</style>')
  end
  return table.concat(ret)
end

print(html([[
<style>
a.date-term-link::after { background: rgb(216, 216, 216); }
.date-term {
  font-size: 0.9rem;
  color: rgb(112, 112, 112);
}
.date-term .date-bracket-start,
.date-term .date-bracket-end {
  font-size: 0.5rem;
  position: relative;
  inset-block-start: -0.15rem;
}
</style>
a1
<style>
.date-term .date-bracket-start { margin-inline-end: 0.2em; }
.date-term .date-bracket-end { margin-inline-start: 0.04em; }
.date-term .date-term-single {
  display: inline-block;
}
.date-term .delim::after { content: '~'; padding-inline: 0.1em 0.2em; }
div[role='separator'] {
  block-size: 1.5em;
  margin-block: 1.5em;
  inline-size: calc(100% - 3em);
  margin-inline-start: 1.5em;
  background: no-repeat center 0 / auto 100% url('/bin/divider-fleuron-heart.svg');
  filter: hue-rotate(282deg);
  position: relative;
}
div[role='separator']::before, div[role='separator']::after {
  content: '';
  display: inline-block;
  block-size: 1.5em;
  inline-size: 1.5em;
  background: no-repeat 0 / contain url('/bin/divider-end.svg');
  position: absolute;
}
div[role='separator']::before { inset-inline-start: -1.5em; }
div[role='separator']::after { inset-inline-end: -1.5em; }
div[role='separator'].item-separator,
div[role='separator'].cloudy {
  background-image: url('/bin/divider-fleuron-cloudy.svg');
  background-repeat: repeat-x;
}
div[role='separator'].windy {
  background-image: url('/bin/divider-fleuron-windy.svg');
  background-repeat: repeat-x;
}

div.item-separator:nth-child(5n+1) { background-position-x: -4em; }
div.item-separator:nth-child(5n+2) { background-position-x: 4em; }
div.item-separator:nth-child(5n+3) { background-position-x: 0em; }
div.item-separator:nth-child(5n+4) { background-position-x: -8em; }
div.item-separator:nth-child(5n+5) { background-position-x: 8em; }

.kaomoji {
  display: inline-block;
  vertical-align: middle;
}
.kaomoji > svg {
  block-size: 1em;
  inline-size: auto;
}

table.file-table {
  margin: 1em 0;
  border-spacing: 1em 0.4em;
}
table.file-table > tbody {
  word-wrap: anywhere;
}
table.file-table .file-table-name {
  margin-inline: 0.2em 0.33em;
}
@media (max-width: 115vh), (max-width: 48rem) {
  table.file-table {
    margin-block-start: -0.4em;
    border-spacing: 1em 0;
  }
  table.file-table tr > td { display: block; }
  table.file-table tr > td:first-child {
    margin-block: 0.5em 0;
    margin-inline: -0.7em -0.4em;
  }
}

ul {
  padding-inline-start: 3em;
  list-style: '–   ';
}

section h1 { font-size: 1.2rem; margin-block-end: 1.08rem; }
section h2 { font-size: 1.14rem; margin-block-end: 1rem; }
section h3 { font-size: 1.08rem; margin-block-end: 1rem; }
blockquote {
  margin: -0.1em 2em -0.1em 1em;
  padding: 0.6em 1em;
  border-inline-start: 0.1em solid hsl(282deg, 100%, 45%);
  background: hsla(282deg, 100%, 45%, 4%);
}
blockquote *:first-child { margin-block-start: 0; }
blockquote *:last-child { margin-block-end: 0; }
blockquote + blockquote { margin-block-start: 0.4em; }

span:lang(lat) { font-style: italic; }

.no-break {
  display: inline-block;
  white-space: nowrap;
}

.music-track {
  display: flex;
  column-gap: 0.5em;
  align-items: center;
}
.music-track img {
  inline-size: 4.75em;
  block-size: 4.75em;
  object-fit: cover;
}
.music-track .orig-title {
  font-size: 0.75em;
  color: #886;
  display: block;
}
</style>

a2

</body></html>
]]))

return {
  html = html,
  css = css,
}
