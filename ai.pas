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
begin
  aiDefenseAtArrival := planets[id].ships + flight * planets[id].production / ProductionPeriod;
end;

function aiTargetScore(id: Integer): Real;
var
  flight, defense: Real;
begin
  flight := traveltime(planets[aiHome].x, planets[aiHome].y, planets[id].x, planets[id].y);
  defense := aiDefenseAtArrival(id, flight);
  aiTargetScore := planets[id].production * 10000.0 / ((defense + 10.0) * flight);
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
    if (id <> aiHome) and (planets[aiHome].owner = 2) and (ownerFleetCount(2) < maxPlayerFleets - 2) then
    begin
      surplus := Int(planets[id].ships - (5 + planets[id].production));
      if (surplus >= 20) and (LaunchFleet(id, aiHome, surplus) > 0) then
        launchedFrom := id;
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
    if (planets[aiHome].owner = 2) and (aiBestTarget > 0) and (not hasComputerFleetTo(aiBestTarget)) then
    begin
      UpdatePlanet(aiHome);
      need := Int(aiDefenseAtArrival(aiBestTarget, traveltime(planets[aiHome].x, planets[aiHome].y, planets[aiBestTarget].x, planets[aiBestTarget].y)) + 10.99);
      if (planets[aiHome].ships - 100.0 >= need) and (need >= 1) then
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
