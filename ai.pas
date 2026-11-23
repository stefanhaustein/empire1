var
  aiPlanet, aiHome, aiNextHome, aiBestHomeDist, aiBestTarget: Integer;
  aiBestScore: Real;

procedure InitAI;
begin
  aiPlanet := 1;
  aiHome := 2;
  aiNextHome := 0;
  aiBestHomeDist := 9999;
  aiBestTarget := 0;
  aiBestScore := -1;
end;

function hasComputerFleetTo(dst: Integer): Boolean;
var
  i: Integer;
begin
  hasComputerFleetTo := False;
  for i := 1 to fleetCount do
    if (fleets[i].owner = 2) and (fleets[i].destination = dst) then
    begin
      hasComputerFleetTo := True;
      Exit;
    end;
end;

function aiDefenseAtArrival(id: Integer; flight: Real): Real;
var
  known, age: Real;
begin
  if planets[id].owner = 2 then
    aiDefenseAtArrival := planets[id].ships + flight * planets[id].production / ProductionPeriod
  else if planets[id].seenTime[2] >= 0 then
  begin
    known := planets[id].seenShips[2];
    age := currentTime - planets[id].seenTime[2];
    if age < 0 then age := 0;
    aiDefenseAtArrival := known + (age + flight) * planets[id].production / ProductionPeriod;
  end
  else
    aiDefenseAtArrival := 180.0 + flight * planets[id].production / ProductionPeriod;
end;

function aiTargetScore(id: Integer): Real;
var
  flight, defense: Real;
begin
  flight := traveltime(planets[aiHome].x, planets[aiHome].y, planets[id].x, planets[id].y);
  defense := aiDefenseAtArrival(id, flight);
  aiTargetScore := planets[id].production * 10000.0 / ((defense + 10.0) * flight);
end;

const
  aiHomeReserve = 50.0;
  aiMinSurplus = 40.0;

function aiMaxFleets: Integer;
begin
  if difficulty = 0 then
    aiMaxFleets := 8
  else if difficulty = 1 then
    aiMaxFleets := 16
  else
    aiMaxFleets := maxPlayerFleets;
end;

function canAiLaunch(isReinf: Boolean): Boolean;
var
  i, att, reinf, limit: Integer;
begin
  att := 0;
  reinf := 0;
  for i := 1 to fleetCount do
    if fleets[i].owner = 2 then
    begin
      if planets[fleets[i].destination].owner = 2 then
        reinf := reinf + 1
      else
        att := att + 1;
    end;
  limit := aiMaxFleets;
  if isReinf then
    canAiLaunch := (att + reinf < limit) and (reinf < limit - 2)
  else
    canAiLaunch := (att + reinf < limit) and (att < limit - 2);
end;

function hasSpottedThreat(id: Integer): Boolean;
var
  i: Integer;
begin
  hasSpottedThreat := False;
  for i := 1 to fleetCount do
    if (fleets[i].destination = id) and (fleets[i].owner <> 2) and (fleets[i].state >= 1) and (fleets[i].state < 3) then
    begin
      hasSpottedThreat := True;
      Exit;
    end;
end;

procedure tryDefendPlanet(id: Integer; var launchedFrom: Integer);
var
  i: Integer;
  attShips, friendlyShips, earliestHit, rem, flight, need: Real;
begin
  attShips := 0;
  earliestHit := 0;
  for i := 1 to fleetCount do
    if (fleets[i].destination = id) and (fleets[i].owner <> 2) and (fleets[i].state = 2) then
    begin
      attShips := attShips + fleets[i].ships;
      if (earliestHit = 0) or (fleets[i].enter < earliestHit) then
        earliestHit := fleets[i].enter;
    end;
  if attShips <= 0 then
    Exit;

  rem := earliestHit - currentTime;
  flight := traveltime(planets[aiHome].x, planets[aiHome].y, planets[id].x, planets[id].y);
  if (rem <= 0) or (flight >= rem) then
    Exit;

  friendlyShips := 0;
  for i := 1 to fleetCount do
    if (fleets[i].destination = id) and (fleets[i].owner = 2) and (fleets[i].state < 3) and (fleets[i].enter < earliestHit) then
      friendlyShips := friendlyShips + fleets[i].ships;

  UpdatePlanet(id);
  UpdatePlanet(aiHome);
  need := Int(attShips + 10.99 - (aiDefenseAtArrival(id, rem) + friendlyShips));
  if (need >= 1) and (planets[aiHome].ships - aiHomeReserve >= need) then
  begin
    if LaunchFleet(aiHome, id, need) > 0 then
      launchedFrom := aiHome;
  end;
end;

procedure TickAI(var launchedFrom: Integer);
var
  id, dx, dy, dist: Integer;
  score, need, surplus: Real;
begin
  launchedFrom := 0;
  id := aiPlanet;
  if planets[id].owner = 2 then
  begin
    if (planets[id].ships >= 30) or (id = aiHome) or (planets[aiHome].owner <> 2) then
    begin
      dx := planets[id].x - 12;
      dy := planets[id].y - 10;
      dist := dx * dx + dy * dy;
      if (aiNextHome = 0) or (dist < aiBestHomeDist) then
      begin
        aiBestHomeDist := dist;
        aiNextHome := id;
      end;
    end;
    if (id <> aiHome) and (planets[aiHome].owner = 2) and canAiLaunch(True) then
    begin
      if hasSpottedThreat(id) then
        tryDefendPlanet(id, launchedFrom)
      else
      begin
        surplus := Int(planets[id].ships - (5 + planets[id].production));
        if (surplus >= aiMinSurplus) and (LaunchFleet(id, aiHome, surplus) > 0) then
          launchedFrom := id;
      end;
    end;
  end
  else if (planets[aiHome].owner = 2) and (not hasComputerFleetTo(id)) then
  begin
    score := aiTargetScore(id);
    if (aiBestTarget = 0) or (score > aiBestScore) then
    begin
      aiBestTarget := id;
      aiBestScore := score;
    end;
  end;

  aiPlanet := aiPlanet + 1;
  if aiPlanet > PlanetCount then
  begin
    aiPlanet := 1;
    if (planets[aiHome].owner = 2) and (aiBestTarget > 0) and (not hasComputerFleetTo(aiBestTarget)) and canAiLaunch(False) then
    begin
      UpdatePlanet(aiHome);
      need := Int(aiDefenseAtArrival(aiBestTarget, traveltime(planets[aiHome].x, planets[aiHome].y, planets[aiBestTarget].x, planets[aiBestTarget].y)) + 10.99);
      if (planets[aiHome].ships - aiHomeReserve >= need) and (need >= 1) then
      begin
        if LaunchFleet(aiHome, aiBestTarget, need) > 0 then
          launchedFrom := aiHome;
      end;
    end;
    if (aiNextHome > 0) and ((difficulty >= 2) or (planets[aiHome].owner <> 2)) then
      aiHome := aiNextHome;
    aiNextHome := 0;
    aiBestHomeDist := 9999;
    aiBestTarget := 0;
    aiBestScore := -1;
  end;
end;
