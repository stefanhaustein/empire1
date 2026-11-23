const
  BottomPaneRows = 3;
  DetailsWidth = 14;
  maxMessages = 23;

type
  str61 = String[61];

var
  topH, splitCol, splitRow, selectedPlanet: Integer;
  inputActive, messagesOpen, overlapFleetOn: Boolean;
  inputPrompt, inputBuf: String;
  lastStardate: str16;
  lastBlinkTime: Real;
  msgLog: array[1..maxMessages] of str61;
  msgColor: array[1..maxMessages] of Integer;
  msgHead, msgCount: Integer;

procedure initUI;
begin
  topH := ScreenHeight - BottomPaneRows - 1;
  splitCol := ScreenWidth - DetailsWidth;
  splitRow := topH + 1;
  selectedPlanet := 1;
  inputActive := False;
  messagesOpen := False;
  overlapFleetOn := True;
  inputPrompt := '';
  inputBuf := '';
  lastStardate := '';
  lastBlinkTime := currentTime;
  msgHead := 0;
  msgCount := 0;
end;

procedure focusInput;
begin
  if inputActive then
    gotoXY(1 + Length(inputPrompt) + Length(inputBuf), splitRow + 3)
  else
    gotoXY(1, splitRow + 3);
end;

function ownerColor(ownerId: Integer): Integer;
begin
  if ownerId = 1 then
    ownerColor := Cyan
  else if ownerId = 2 then
    ownerColor := Red
  else
    ownerColor := Green;
end;

procedure setOwnerColor(ownerId: Integer);
begin
  TextColor(ownerColor(ownerId));
end;

procedure setMsgColor(tag: Integer);
begin
  if tag < 0 then
    TextColor(White)
  else
    setOwnerColor(tag);
end;

procedure renderHorizDivider;
var
  x: Integer;
begin
  gotoXY(1, splitRow);
  for x := 1 to ScreenWidth do
    if x = splitCol then
      write('+')
    else
      write('-');
end;

procedure renderLines;
var
  y: Integer;
begin
  TextColor(White);
  ClrScr;

  for y := 1 to ScreenHeight do
  begin
    gotoXY(splitCol, y);
    write('|');
  end;

  renderHorizDivider;
end;

function starScreenX(px: Integer): Integer;
begin
  starScreenX := 1 + (px * (splitCol - 4)) div (GridW - 1);
end;

function starScreenY(py: Integer): Integer;
begin
  starScreenY := 1 + (py * (topH - 1)) div (GridH - 1);
end;

function planetChar(var p: PlanetRec): Char;
var
  ch: Char;
begin
  if p.owner = 1 then
    ch := 'p'
  else if p.owner = 2 then
    ch := 'c'
  else
    ch := 'n';
  if p.production >= 4 then
    ch := UpCase(ch);
  planetChar := ch;
end;

procedure renderPlanet(i: Integer);
begin
  if messagesOpen then
    Exit;
  gotoXY(starScreenX(Planets[i].x), starScreenY(Planets[i].y));
  if i = selectedPlanet then
  begin
    TextBackground(ownerColor(Planets[i].owner));
    TextColor(Black);
  end
  else
    setOwnerColor(Planets[i].owner);
  write(planetChar(Planets[i]), i);
  if i = selectedPlanet then
    TextBackground(Black);
  TextColor(White);
end;

procedure renderStarChart;
var
  i: Integer;
begin
  for i := 1 to PlanetCount do
    renderPlanet(i);
end;

function planetLabelWidth(planetId: Integer): Integer;
begin
  if planetId < 10 then
    planetLabelWidth := 2
  else
    planetLabelWidth := 3;
end;

function planetAtCell(x, y: Integer): Integer;
var
  i, px, py: Integer;
begin
  planetAtCell := 0;
  for i := 1 to PlanetCount do
  begin
    py := starScreenY(Planets[i].y);
    if y = py then
    begin
      px := starScreenX(Planets[i].x);
      if (x >= px) and (x < px + planetLabelWidth(i)) then
      begin
        planetAtCell := i;
        Exit;
      end;
    end;
  end;
end;

function isFleetVisible(slot: Integer): Boolean;
begin
  isFleetVisible := (fleets[slot].state < 3) and ((difficulty = 0) or (fleets[slot].owner = 1) or (fleets[slot].state >= 1));
end;

function fleetAtCell(x, y, skipSlot: Integer): Integer;
var
  i: Integer;
begin
  fleetAtCell := 0;
  for i := 1 to fleetCount do
    if (i <> skipSlot) and isFleetVisible(i) and (fleets[i].sx = x) and (fleets[i].sy = y) then
    begin
      fleetAtCell := i;
      Exit;
    end;
end;

function fleetGlyph(slot: Integer): Char;
var
  s: Real;
  tier: Integer;
  glyphs: str16;
begin
  if (difficulty > 0) and (fleets[slot].owner <> 1) and (fleets[slot].state < 2) then
    fleetGlyph := '?'
  else
  begin
    s := fleets[slot].ships;
    if s >= 1024 then
      tier := 3
    else if s >= 256 then
      tier := 2
    else
      tier := 1;
    if fleets[slot].owner = 1 then
      glyphs := 'oO@'
    else
      glyphs := '+*#';
    fleetGlyph := glyphs[tier];
  end;
end;

procedure drawFleet(slot: Integer);
begin
  if messagesOpen or (fleets[slot].sx <= 0) then
    Exit;
  if (not overlapFleetOn) and (planetAtCell(fleets[slot].sx, fleets[slot].sy) > 0) then
    Exit;
  gotoXY(fleets[slot].sx, fleets[slot].sy);
  setOwnerColor(fleets[slot].owner);
  write(fleetGlyph(slot));
  TextColor(White);
  focusInput;
end;

procedure restorePlanet(p, skipSlot: Integer);
var
  i: Integer;
begin
  renderPlanet(p);
  if overlapFleetOn then
    for i := 1 to fleetCount do
      if (i <> skipSlot) and isFleetVisible(i) and (planetAtCell(fleets[i].sx, fleets[i].sy) = p) then
        drawFleet(i);
  focusInput;
end;

procedure eraseFleet(slot: Integer);
var
  p, other: Integer;
begin
  if messagesOpen or (fleets[slot].sx <= 0) then
    Exit;
  other := fleetAtCell(fleets[slot].sx, fleets[slot].sy, slot);
  p := planetAtCell(fleets[slot].sx, fleets[slot].sy);
  if other > 0 then
  begin
    if (p = 0) or overlapFleetOn then
      drawFleet(other);
  end
  else if p > 0 then
    restorePlanet(p, slot)
  else
  begin
    gotoXY(fleets[slot].sx, fleets[slot].sy);
    write(' ');
    focusInput;
  end;
end;

procedure updateFleetBlink;
var
  i, p: Integer;
  changed: Boolean;
begin
  if currentTime - lastBlinkTime < 0.5 then
    Exit;
  lastBlinkTime := currentTime;
  overlapFleetOn := not overlapFleetOn;
  if messagesOpen then
    Exit;
  changed := False;
  for i := 1 to fleetCount do
    if (fleets[i].sx > 0) and isFleetVisible(i) then
    begin
      p := planetAtCell(fleets[i].sx, fleets[i].sy);
      if p > 0 then
      begin
        changed := True;
        if overlapFleetOn then
          drawFleet(i)
        else
          renderPlanet(p);
      end;
    end;
  if changed then
    focusInput;
end;

procedure updateFleetPos(slot: Integer);
var
  x0, y0, x1, y1, nx, ny: Integer;
  t: Real;
begin
  x0 := starScreenX(Planets[fleets[slot].Source].x);
  y0 := starScreenY(Planets[fleets[slot].Source].y);
  x1 := starScreenX(Planets[fleets[slot].destination].x);
  y1 := starScreenY(Planets[fleets[slot].destination].y);
  t := (currentTime - fleets[slot].start) / (fleets[slot].enter - fleets[slot].start);
  if t < 0 then t := 0
  else if t > 1 then t := 1;
  nx := x0 + round(t * (x1 - x0));
  ny := y0 + round(t * (y1 - y0));
  if (nx <> fleets[slot].sx) or (ny <> fleets[slot].sy) then
  begin
    eraseFleet(slot);
    fleets[slot].sx := nx;
    fleets[slot].sy := ny;
    drawFleet(slot);
  end;
end;

procedure writePadded(x, y, w: Integer; s: String);
begin
  gotoXY(x, y);
  write(Copy(AlignStr(s, w), 1, w));
end;

procedure writeRHS(row: Integer; s: String);
begin
  writePadded(splitCol + 2, row, DetailsWidth - 2, s);
end;

function formatStardate(t: Real): str16;
var
  s: str16;
begin
  Str(Int(t / (StardatePeriod * 0.1)) / 10.0:0:1, s);
  formatStardate := s;
end;

function stardateStr: str16;
begin
  stardateStr := formatStardate(currentTime);
end;

procedure renderStardate;
var
  s: str16;
begin
  s := stardateStr;
  if s <> lastStardate then
  begin
    lastStardate := s;
    writeRHS(1, AlignStr(s, -(DetailsWidth - 2)));
    focusInput;
  end;
end;

procedure writeMenuItem(row: Integer; key: Char; rest: String);
begin
  gotoXY(splitCol + 2, row);
  TextColor(White);
  write('[');
  TextColor(Yellow);
  write(key);
  TextColor(White);
  write(Copy(AlignStr(']' + rest, DetailsWidth - 4), 1, DetailsWidth - 4));
end;

procedure renderMenu(planetId: Integer);
begin
  writeMenuItem(splitRow - 5, 'P', 'lanet');
  if Planets[planetId].owner = 1 then
    writeMenuItem(splitRow - 4, 'S', 'end to')
  else
    writeMenuItem(splitRow - 4, 'S', 'end from');
  if messagesOpen then
    writeMenuItem(splitRow - 3, 'M', 'ap')
  else
    writeMenuItem(splitRow - 3, 'M', 'essages');
  writeMenuItem(splitRow - 1, 'R', 'estart');
  writeMenuItem(splitRow + 1, 'Q', 'uit');
end;

procedure renderPlanetShipInfo(planetId: Integer);
var
  p: PlanetRec;
begin
  p := Planets[planetId];
  setOwnerColor(p.owner);
  if (p.owner = 1) or (difficulty = 0) then
  begin
    writeRHS(8, '  ' + Real2Str(p.ships, 0));
    writeRHS(11, '');
    writeRHS(12, '');
  end
  else if p.seenTime[1] >= 0 then
  begin
    writeRHS(8, '  ~' + Real2Str(p.seenShips[1], 0));
    writeRHS(11, 'Seen:');
    writeRHS(12, '  ' + formatStardate(p.seenTime[1]));
  end
  else
  begin
    writeRHS(8, '  ???');
    writeRHS(11, '');
    writeRHS(12, '');
  end;
  TextColor(White);
end;

procedure renderPlanetShips(planetId: Integer);
begin
  renderPlanetShipInfo(planetId);
  focusInput;
end;

procedure renderPlanetDetails(planetId: Integer);
var
  p: PlanetRec;
begin
  p := Planets[planetId];
  writeRHS(2, '');
  setOwnerColor(p.owner);
  writeRHS(3, 'Planet:');
  writeRHS(4, '  #' + Int2Str(planetId, 0) + ' (' + Chr(Ord('A') + p.x) + Int2Str(p.y + 1, 0) + ')');
  writeRHS(5, 'Owner:');
  writeRHS(6, '  ' + p.ownerName);
  writeRHS(7, 'Ships:');
  writeRHS(9, 'Production:');
  writeRHS(10, '  ' + Int2Str(p.production, 0) + '/wk');
  renderPlanetShipInfo(planetId);
  renderMenu(planetId);
  focusInput;
end;

procedure writeMsgLine(x, y, w, tag: Integer; s: String);
begin
  setMsgColor(tag);
  writePadded(x, y, w, s);
  TextColor(White);
end;

procedure renderMessages;
var
  topRow, row, idx, shown: Integer;
begin
  if messagesOpen then
    topRow := 1
  else
    topRow := splitRow + 1;

  row := splitRow + 2;
  if (msgCount = 0) and messagesOpen then
  begin
    writePadded(1, row, splitCol - 1, '(no messages)');
    row := row - 1;
  end
  else
  begin
    idx := msgHead;
    shown := 0;
    while (row >= topRow) and (shown < msgCount) do
    begin
      writeMsgLine(1, row, splitCol - 1, msgColor[idx], msgLog[idx]);
      row := row - 1;
      shown := shown + 1;
      idx := idx - 1;
      if idx < 1 then
        idx := maxMessages;
    end;
  end;
  while row >= topRow do
  begin
    writePadded(1, row, splitCol - 1, '');
    row := row - 1;
  end;
end;

procedure toggleMessages(planetId: Integer);
var
  i: Integer;
begin
  messagesOpen := not messagesOpen;
  if messagesOpen then
    renderMessages
  else
  begin
    for i := 1 to topH do
      writePadded(1, i, splitCol - 1, '');
    renderHorizDivider;
    renderMessages;
    renderStarChart;
    for i := 1 to fleetCount do
      if (fleets[i].state < 3) and (fleets[i].sx > 0) and isFleetVisible(i) then
        drawFleet(i);
  end;
  renderMenu(planetId);
  focusInput;
end;

procedure showStatus(msg: String; colorTag: Integer);
begin
  if not messagesOpen then
  begin
    if msgCount > 0 then
      writeMsgLine(1, splitRow + 1, splitCol - 1, msgColor[msgHead], msgLog[msgHead])
    else
      writePadded(1, splitRow + 1, splitCol - 1, '');
  end;
  writeMsgLine(1, splitRow + 2, splitCol - 1, colorTag, stardateStr + ': ' + msg);
  focusInput;
end;

procedure showColoredMessage(msg: String; colorTag: Integer);
var
  entry: str61;
begin
  if msg = '' then
  begin
    if not messagesOpen then
      renderMessages;
    focusInput;
    Exit;
  end;
  entry := Copy(stardateStr + ': ' + msg, 1, splitCol - 2);
  msgHead := msgHead + 1;
  if msgHead > maxMessages then
    msgHead := 1;
  if msgCount < maxMessages then
    msgCount := msgCount + 1;
  msgLog[msgHead] := entry;
  msgColor[msgHead] := colorTag;
  renderMessages;
  focusInput;
end;

procedure showMessage(msg: String);
begin
  showColoredMessage(msg, -1);
end;

procedure startPrompt(prompt: String);
begin
  inputActive := True;
  inputPrompt := prompt;
  inputBuf := '';
  writePadded(1, splitRow + 3, splitCol - 1, prompt);
  focusInput;
end;

procedure clearPrompt;
begin
  inputActive := False;
  inputPrompt := '';
  inputBuf := '';
  writePadded(1, splitRow + 3, splitCol - 1, '');
  focusInput;
end;

function handlePromptKey(ch: Char; var resultStr: String): Integer;
begin
  handlePromptKey := 0;
  if (ch = #13) or (ch = #10) then
  begin
    resultStr := inputBuf;
    clearPrompt;
    handlePromptKey := 1;
  end
  else if ch = #27 then
  begin
    clearPrompt;
    handlePromptKey := -1;
  end
  else if (ch = #8) or (ch = #127) then
  begin
    if Length(inputBuf) > 0 then
    begin
      inputBuf := Copy(inputBuf, 1, Length(inputBuf) - 1);
      focusInput;
      write(' ');
      focusInput;
    end;
  end
  else if (ch >= ' ') and (Length(inputBuf) < 16) then
  begin
    inputBuf := inputBuf + ch;
    write(ch);
  end;
end;