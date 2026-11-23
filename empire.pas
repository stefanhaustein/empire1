program Empire;

{$ifdef FPC}
uses Crt;
{$endif}

{$i str.pas}
{$i model.pas}
{$i ai.pas}
{$i ui.pas}

var
  tickPlanet, tickFleet, promptMode, sendSource, sendDest, gameWinner: Integer;
  tickOdd: Boolean;

procedure selectPlanet(arg: String);
var
  n, err, oldSelected: Integer;
begin
  arg := TrimStr(arg);
  if arg = '' then
  begin
    showMessage('');
    Exit;
  end;
  Val(arg, n, err);
  if (err <> 0) or (n < 1) or (n > PlanetCount) then
    showMessage('Invalid planet (1-' + Int2Str(PlanetCount) + ')')
  else
  begin
    oldSelected := selectedPlanet;
    selectedPlanet := n;
    UpdatePlanet(n);
    if oldSelected <> n then
      restorePlanet(oldSelected, 0);
    restorePlanet(n, 0);
    renderPlanetDetails(n);
    showMessage('Selected planet ' + Int2Str(n));
  end;
end;

procedure startSendCommand;
begin
  if Planets[selectedPlanet].owner = 1 then
  begin
    sendSource := selectedPlanet;
    sendDest := 0;
    promptMode := 2;
    startPrompt('Target planet: ');
  end
  else
  begin
    sendSource := 0;
    sendDest := selectedPlanet;
    promptMode := 2;
    startPrompt('Source planet: ');
  end;
end;

procedure handleSendPlanet(arg: String);
var
  n, err: Integer;
begin
  arg := TrimStr(arg);
  if arg = '' then
  begin
    showMessage('');
    Exit;
  end;
  Val(arg, n, err);
  if (err <> 0) or (n < 1) or (n > PlanetCount) then
  begin
    showMessage('Invalid planet (1-' + Int2Str(PlanetCount) + ')');
    Exit;
  end;

  if sendSource <> 0 then
  begin
    if n = sendSource then
    begin
      showMessage('Cannot send to same planet');
      Exit;
    end;
    sendDest := n;
  end
  else
  begin
    if Planets[n].owner <> 1 then
    begin
      showMessage('Not your planet');
      Exit;
    end;
    sendSource := n;
  end;

  UpdatePlanet(sendSource);
  if Planets[sendSource].ships < 1 then
  begin
    showMessage('No ships on planet #' + Int2Str(sendSource));
    Exit;
  end;
  promptMode := 3;
  startPrompt('Ships [' + Real2Str(Int(Planets[sendSource].ships)) + ']: ');
end;

procedure handleSendCount(arg: String);
var
  count: Real;
  err, slot: Integer;
begin
  arg := TrimStr(arg);
  UpdatePlanet(sendSource);
  if Planets[sendSource].owner <> 1 then
    showMessage('Source planet lost')
  else if Planets[sendSource].ships < 1 then
    showMessage('No ships on planet #' + Int2Str(sendSource))
  else
  begin
    if arg = '' then
    begin
      count := Int(Planets[sendSource].ships);
      err := 0;
    end
    else
    begin
      Val(arg, count, err);
      count := Int(count);
    end;
    if (err <> 0) or (count < 1) or (count > Int(Planets[sendSource].ships)) then
      showMessage('Invalid ship count')
    else
    begin
      slot := LaunchFleet(sendSource, sendDest, count);
      if slot = 0 then
        showMessage('Hyperspace traffic jam!')
      else
      begin
        if selectedPlanet = sendSource then
          renderPlanetShips(selectedPlanet);
        showColoredMessage('Sent ' + Real2Str(count) + ' #' + Int2Str(sendSource) + '->#' + Int2Str(sendDest) + ' (' + Real2Str(fleets[slot].enter - currentTime) + 'd)', 1);
      end;
    end;
  end;
end;

procedure tickPlanetStep;
var
  launchedFrom: Integer;
  oldShips, newShips: String;
begin
  if (tickPlanet = selectedPlanet) and ((Planets[tickPlanet].owner = 1) or (difficulty = 0)) then
  begin
    oldShips := Real2Str(Planets[tickPlanet].ships);
    UpdatePlanet(tickPlanet);
    newShips := Real2Str(Planets[tickPlanet].ships);
    if newShips <> oldShips then
      renderPlanetShips(tickPlanet);
  end
  else
    UpdatePlanet(tickPlanet);
  tickPlanet := tickPlanet + 1;
  if tickPlanet > PlanetCount then
    tickPlanet := 1;

  TickAI(launchedFrom);
  if launchedFrom = selectedPlanet then
    renderPlanetShips(selectedPlanet);
  renderStardate;
end;

function ownerCode(ownerId: Integer): Char;
begin
  case ownerId of
    1: ownerCode := 'P';
    2: ownerCode := 'C';
  else
    ownerCode := 'N';
  end;
end;

procedure checkFleetSensors(slot: Integer);
const
  SpotRange = 100.0;
  ScanRange = 50.0;
var
  dst: Integer;
  rem: Real;
begin
  dst := fleets[slot].destination;
  if ((fleets[slot].owner = 1) and (planets[dst].owner = 2)) or
     ((fleets[slot].owner <> 1) and (planets[dst].owner = 1)) then
  begin
    rem := fleets[slot].enter - currentTime;
    if (fleets[slot].state < 2) and (rem <= ScanRange) then
    begin
      fleets[slot].state := 2;
      if fleets[slot].owner <> 1 then
      begin
        showColoredMessage('Incoming fleet (' + Real2Str(fleets[slot].ships) + ') at #' + Int2Str(dst), fleets[slot].owner);
        drawFleet(slot);
      end;
    end
    else if (fleets[slot].state = 0) and (rem <= SpotRange) then
    begin
      fleets[slot].state := 1;
      if fleets[slot].owner <> 1 then
        showColoredMessage('Incoming fleet at #' + Int2Str(dst), fleets[slot].owner);
    end;
  end
  else if fleets[slot].state >= 1 then
  begin
    if (fleets[slot].owner <> 1) and (difficulty > 0) then
    begin
      eraseFleet(slot);
      fleets[slot].sx := 0;
      fleets[slot].sy := 0;
    end;
    fleets[slot].state := 0;
  end;
  if (fleets[slot].owner = 1) or (difficulty = 0) or (fleets[slot].state >= 1) then
    updateFleetPos(slot);
end;

procedure tickFleetStep;
var
  dst, attOwner, winner: Integer;
  finished, captured, wasHostile, playerInvolved: Boolean;
begin
  if fleetCount = 0 then
    Exit;
  if tickFleet > fleetCount then
    tickFleet := 1;
  if currentTime >= fleets[tickFleet].enter then
  begin
    dst := fleets[tickFleet].destination;
    attOwner := fleets[tickFleet].owner;
    wasHostile := attOwner <> planets[dst].owner;
    playerInvolved := (attOwner = 1) or (planets[dst].owner = 1);
    if fleets[tickFleet].state < 3 then
    begin
      eraseFleet(tickFleet);
      fleets[tickFleet].sx := 0;
      fleets[tickFleet].sy := 0;
      fleets[tickFleet].state := 3;
    end;
    StepFleetArrival(tickFleet, finished, captured);
    if not finished then
    begin
      if dst = selectedPlanet then
        renderPlanetShips(dst);
      if playerInvolved then
        showStatus('#' + Int2Str(dst) + ' battle: ' + ownerCode(attOwner) + ' ' + Real2Str(fleets[tickFleet].ships) + ' vs ' + ownerCode(planets[dst].owner) + ' ' + Real2Str(planets[dst].ships), attOwner);
      tickFleet := tickFleet + 1;
    end
    else
    begin
      if captured then
        restorePlanet(dst, 0);
      if dst = selectedPlanet then
      begin
        if captured then
          renderPlanetDetails(dst)
        else
          renderPlanetShips(dst);
      end;
      if captured then
        showColoredMessage('#' + Int2Str(dst) + ' captured by ' + planets[dst].ownerName, planets[dst].owner)
      else if wasHostile and playerInvolved then
        showColoredMessage('#' + Int2Str(dst) + ' held (' + Real2Str(planets[dst].ships) + ' left)', planets[dst].owner)
      else if (not wasHostile) and (attOwner = 1) then
        showColoredMessage('Fleet arrived at #' + Int2Str(dst), 1);
      if gameWinner = 0 then
      begin
        winner := checkWinner;
        if winner > 0 then
        begin
          gameWinner := winner;
          case winner of
            1: showColoredMessage('Victory! All enemy forces defeated.', 1);
            2: showColoredMessage('Defeat! All your forces were lost.', 2);
          else
            showMessage('Draw! Both empires destroyed.');
          end;
          showMessage('Press R to restart or Q to quit.');
        end;
      end;
    end;
  end
  else
  begin
    checkFleetSensors(tickFleet);
    tickFleet := tickFleet + 1;
  end;
  if tickFleet > fleetCount then
    tickFleet := 1;
end;

procedure tickBackground;
begin
  Delay(20);
  currentTime := currentTime + 0.02;
  if tickOdd then
    tickFleetStep
  else
    tickPlanetStep;
  tickOdd := not tickOdd;
  updateFleetBlink;
end;

procedure promptDifficulty;
const
  DiffPrompt = 'Difficulty (0:Easy 1:Norm 2:Hard) [0]: ';
var
  ch: Char;
  arg: String;
  status, level, err: Integer;
  chosen: Boolean;
begin
  chosen := False;
  difficulty := 0;
  showMessage('Shall we play a game?');
  startPrompt(DiffPrompt);
  repeat
    ch := ReadKey;
    if ch = #0 then
      ch := ReadKey
    else
    begin
      status := handlePromptKey(ch, arg);
      if status = -1 then
        chosen := True
      else if status = 1 then
      begin
        arg := TrimStr(arg);
        if arg = '' then
          chosen := True
        else
        begin
          Val(arg, level, err);
          if (err = 0) and (level >= 0) and (level <= 2) then
          begin
            difficulty := level;
            chosen := True;
          end
          else
          begin
            showMessage('Enter 0, 1, or 2');
            startPrompt(DiffPrompt);
          end;
        end;
      end;
    end;
  until chosen;
  showMessage('Difficulty ' + Int2Str(difficulty) + ' active');
end;

procedure startNewGame;
begin
  initModel;
  initAI;
  initUI;
  tickPlanet := 1;
  tickFleet := 1;
  tickOdd := False;
  gameWinner := 0;
  promptMode := 0;
  renderLines;
  renderStarChart;
  renderPlanetDetails(1);
  renderStardate;
  promptDifficulty;
end;

function isYes(arg: String): Boolean;
begin
  arg := ToUpper(TrimStr(arg));
  isYes := (arg = 'Y') or (arg = 'YES');
end;

procedure finishQuit(var done: Boolean);
begin
  if gameWinner <> 1 then
    showMessage('Resigning command. The computer sends its regards.');
  done := True;
end;

procedure runLoop;
var
  ch: Char;
  arg: String;
  status, mode: Integer;
  done: Boolean;
begin
  done := False;
  promptMode := 0;
  showMessage('');
  repeat
    while KeyPressed and not done do
    begin
      ch := ReadKey;
      if ch = #0 then
        ch := ReadKey
      else if inputActive then
      begin
        status := handlePromptKey(ch, arg);
        if status = 1 then
        begin
          mode := promptMode;
          promptMode := 0;
          case mode of
            1: selectPlanet(arg);
            2: handleSendPlanet(arg);
            3: handleSendCount(arg);
            4: if isYes(arg) then startNewGame;
            5: if isYes(arg) then finishQuit(done);
          end;
        end
        else if status = -1 then
        begin
          promptMode := 0;
          showMessage('Cancelled');
        end;
      end
      else
      begin
        case UpCase(ch) of
          'P': begin
            promptMode := 1;
            startPrompt('Planet ID: ');
          end;
          'S': startSendCommand;
          'M': toggleMessages(selectedPlanet);
          #27: if messagesOpen then toggleMessages(selectedPlanet);
          'R': if gameWinner > 0 then
            startNewGame
          else
          begin
            promptMode := 4;
            startPrompt('Restart? (y/n): ');
          end;
          'Q': if gameWinner > 0 then
            finishQuit(done)
          else
          begin
            promptMode := 5;
            startPrompt('Quit? (y/n): ');
          end;
        end;
      end;
    end;
    if not done then
      tickBackground;
  until done;
end;

begin
  startNewGame;
  runLoop;
  TextColor(White);
  gotoXY(1, ScreenHeight);
end.