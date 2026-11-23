type 
  planetRec = record
    production: Integer;      (* Ships per week             *)
    ships: Real;              (* Ships                      *)
    owner,                    (* Player number              *)
    x, y: Integer;            (* Coordinates                *)
    ownerName: str16;         (* Redundant to avoid lookup  *)
    last: Real;               (* Last access timestamp      *)
    seenShips: array[1..2] of Real;
    seenTime: array[1..2] of Real;
  end;

  
  fleetRec = record
    state: Integer;           (* 0=hidden,1=spot,2=size,3=battle *)
    ships: Real;              (* Ships in fleet.            *)
    start,                    (* Depart timestamp           *)
    enter: Real;              (* Arrive timestamp           *)
    Source,                   (* Origin planet id           *)
    sx, sy,                   (* Current position           *)
    destination,              (* Target planet id           *)
    owner: Integer;           (* Owner id                   *)
    ownerName: str16;         (* Redundant to avoid lookup  *)
  end;

const
  planetCount = 30;
  GridW = 25;
  GridH = 20;
  maxPlayerFleets = 32;
  maxFleets = 64;             (* 2 * maxPlayerFleets *)
  ProductionPeriod = 7.0;     (* Seconds (days) per production week *)
  YearDays = 365.0;           (* Days per stardate year *)

var
  planets: array[1..planetCount] of planetRec;
  fleets: array[1..maxFleets] of fleetRec;
  fleetCount, difficulty, baseYear: Integer;
  currentTime: Real;

procedure UpdatePlanet(planetId: Integer);
var
  elapsed: Real;
begin
  elapsed := currentTime - planets[planetId].last;
  if elapsed > 0 then
  begin
    planets[planetId].ships := planets[planetId].ships + elapsed * planets[planetId].production / ProductionPeriod;
    planets[planetId].last := currentTime;
  end;
end;

function traveltime(x0, y0, x1, y1: Integer): Real;
begin
  traveltime := round(sqrt(sqr(x0 - x1) + sqr(y0 - y1))) * 8 + 20;
end;


function isFreePos(x, y, placedCount: Integer): Boolean;
var
  i: Integer;
  ok: Boolean;
begin
  ok := True;
  i := 1;
  while (i <= placedCount) and ok do
  begin
    if sqr(x - planets[i].x) + sqr(y - planets[i].y) < 5 then
      ok := False;
    i := i + 1;
  end;
  isFreePos := ok;
end;

procedure InitModel;
var
  planet: planetRec;
  n, tries: Integer;

begin
  Randomize;
  baseYear := 2000 + random(7000);
  currentTime := random(40) * 9.0;
  for n := 1 to PlanetCount do
  begin
    planet.production := 1 + random(5);
    planet.ships := 50 + random(250);
    planet.owner := 0;
    planet.last := currentTime;
    planet.seenShips[1] := -1;
    planet.seenTime[1] := -1;
    planet.seenShips[2] := -1;
    planet.seenTime[2] := -1;
    if n = 1 then
    begin
      planet.ownername := 'Player';
      planet.owner := 1;
      planet.production := 10;
      planet.ships := 1000;
      planet.x := 19;
      planet.y := 5;
    end
    else if n = 2 then
    begin
      planet.ownername := 'Computer';
      planet.owner := 2;
      planet.production := 10;
      planet.ships := 1000;
      planet.x := 5;
      planet.y := 14;
    end
    else
    begin
      planet.ownername := 'Neutral';
      tries := 0;
      repeat
        if (tries < 50) and (random(3) = 0) then
        begin
          planet.x := round(((Random + Random) * 0.5) * (GridW - 1));
          planet.y := round(((Random + Random) * 0.5) * (GridH - 1));
        end
        else
        begin
          planet.x := random(GridW);
          planet.y := random(GridH);
        end;
        if planet.x < 0 then planet.x := 0
        else if planet.x >= GridW then planet.x := GridW - 1;
        if planet.y < 0 then planet.y := 0
        else if planet.y >= GridH then planet.y := GridH - 1;
        tries := tries + 1;
      until isFreePos(planet.x, planet.y, n - 1) or (tries >= 100);
    end;
    planets[n] := planet;
  end;
  fleetCount := 0;
  difficulty := 0;
end;

function ownerFleetCount(ownerId: Integer): Integer;
var
  i, c: Integer;
begin
  c := 0;
  for i := 1 to fleetCount do
    if fleets[i].owner = ownerId then
      c := c + 1;
  ownerFleetCount := c;
end;

function ownerPlanetCount(ownerId: Integer): Integer;
var
  i, c: Integer;
begin
  c := 0;
  for i := 1 to PlanetCount do
    if planets[i].owner = ownerId then
      c := c + 1;
  ownerPlanetCount := c;
end;

function checkWinner: Integer;
var
  pAlive, cAlive: Boolean;
begin
  pAlive := (ownerPlanetCount(1) > 0) or (ownerFleetCount(1) > 0);
  cAlive := (ownerPlanetCount(2) > 0) or (ownerFleetCount(2) > 0);
  if pAlive and cAlive then
    checkWinner := 0
  else if pAlive then
    checkWinner := 1
  else if cAlive then
    checkWinner := 2
  else
    checkWinner := 3;
end;

function LaunchFleet(src, dst: Integer; count: Real): Integer;
var
  i: Integer;
begin
  if (fleetCount >= maxFleets) or (ownerFleetCount(planets[src].owner) >= maxPlayerFleets) then
  begin
    LaunchFleet := 0;
    Exit;
  end;

  UpdatePlanet(src);
  planets[src].ships := planets[src].ships - count;
  fleetCount := fleetCount + 1;
  i := fleetCount;
  fleets[i].state := 0;
  fleets[i].ships := count;
  fleets[i].start := currentTime;
  fleets[i].enter := currentTime + traveltime(planets[src].x, planets[src].y, planets[dst].x, planets[dst].y);
  fleets[i].Source := src;
  fleets[i].sx := 0;
  fleets[i].sy := 0;
  fleets[i].destination := dst;
  fleets[i].owner := planets[src].owner;
  fleets[i].ownerName := planets[src].ownerName;
  LaunchFleet := i;
end;

procedure StepFleetArrival(slot: Integer; var finished, captured: Boolean);
var
  dst, oldOwner, attOwner: Integer;
  attLoss, defLoss: Real;
begin
  dst := fleets[slot].destination;
  oldOwner := planets[dst].owner;
  attOwner := fleets[slot].owner;
  UpdatePlanet(dst);
  captured := False;
  if attOwner = oldOwner then
  begin
    planets[dst].ships := planets[dst].ships + fleets[slot].ships;
    finished := True;
  end
  else
  begin
    attLoss := planets[dst].ships * (0.1 + Random * 0.2);
    defLoss := fleets[slot].ships * (0.1 + Random * 0.2);
    if attLoss < 1 then attLoss := 1;
    if defLoss < 1 then defLoss := 1;
    fleets[slot].ships := fleets[slot].ships - attLoss;
    planets[dst].ships := planets[dst].ships - defLoss;

    if (fleets[slot].ships < 1) and (planets[dst].ships < 1) then
    begin
      planets[dst].ships := 0;
      finished := True;
    end
    else if planets[dst].ships < 1 then
    begin
      planets[dst].ships := fleets[slot].ships;
      planets[dst].owner := attOwner;
      planets[dst].ownerName := fleets[slot].ownerName;
      captured := True;
      finished := True;
    end
    else if fleets[slot].ships < 1 then
      finished := True
    else
    begin
      fleets[slot].enter := currentTime + 0.6;
      finished := False;
    end;

    if (attOwner = 1) or (attOwner = 2) then
    begin
      planets[dst].seenShips[attOwner] := planets[dst].ships;
      planets[dst].seenTime[attOwner] := currentTime;
    end;
    if captured and ((oldOwner = 1) or (oldOwner = 2)) then
    begin
      planets[dst].seenShips[oldOwner] := planets[dst].ships;
      planets[dst].seenTime[oldOwner] := currentTime;
    end;
  end;

  if finished then
  begin
    if slot < fleetCount then
      fleets[slot] := fleets[fleetCount];
    fleetCount := fleetCount - 1;
  end;
end;
