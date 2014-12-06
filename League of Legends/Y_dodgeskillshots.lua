require 'winapi'
require 'vals_lib'
local uiconfig = require 'uiconfig'
local send = require 'SendInputScheduled'
local version = '1.16' -- Originally from Val, edited by Yibiki
local skillshotArray = {}
local colorcyan,coloryellow = 0xFF00FFFF,0xFFFFFF00
local xa,xb,ya,yb = 100/1920*GetScreenX(),1820/1920*GetScreenX(),100/1080*GetScreenY(),980/1080*GetScreenY()
local cc,locus,block,block_timer = 0,false,false,GetClock()
local add_move_range = (GetDistance(GetMinBBox(myHero)))*.7
local add_radius_range = (GetDistance(GetMinBBox(myHero)))*.7

function Main()
	CheckLocus()
	if GetClock()-block_timer<DodgeConfig.Block_Time then _G.evade = true
	elseif GetClock()-block_timer>DodgeConfig.Block_Time then _G.evade = false end
	Skillshots()
	send.tick()
end

	DodgeConfig, menu = uiconfig.add_menu('DodgeSkillshot Config', 250)
	menu.checkbutton('DrawSkillShots', 'Draw Skillshots', true)
	menu.checkbutton('DodgeSkillShots', 'Dodge Skillshots', true)
	menu.checkbutton('DodgeSkillShotsAOE', 'Dodge Skillshots for AOE', true)
	menu.checkbutton('Block_User_Input', 'Block User Input', false)
	menu.slider('Block_Time', 'Block User Input time', 0, 2000, 1000)
	
function MakeStateMatch(changes)
    for scode,flag in pairs(changes) do    
        print(scode)
        if flag then print('went down') else print('went up') end
        local vk = winapi.map_virtual_key(scode, 3)
        local is_down = winapi.get_async_key_state(vk)
        if flag then -- went down
            if is_down then
                send.wait(60)
                send.key_down(scode)
                send.wait(60)
            else
                -- up before, up after, down during, we don't care
            end            
        else -- went up
            if is_down then
                -- down before, down after, up during, we don't care
            else
                send.wait(60)
                send.key_up(scode)
                send.wait(60)
            end
        end
    end
end

function CheckLocus()
	if myHero.name=='Katarina' and CountEnemyHeroInRange(550)==0 then locus = false end
	if Fiddle_Timer~=nil and GetTickCount()-Fiddle_Timer>1750 then
		locus = false
		Fiddle_Timer = nil
	end
	if Janna_Timer~=nil and GetTickCount()-Janna_Timer>3250 then
		locus = false
		Janna_Timer = nil
	end
	if Katarina_Timer~=nil and GetTickCount()-Katarina_Timer>2750 then
		locus = false
		Katarina_Timer = nil
	end
	if Karthus_Timer~=nil and GetTickCount()-Karthus_Timer>3250 then
		locus = false
		Karthus_Timer = nil
	end
	for i = 1, objManager:GetMaxDelObjects(), 1 do
		local object = {objManager:GetDelObject(i)}
		local ret={}
		ret.index=object[1]
		ret.name=object[2]
		ret.charName=object[3]
		ret.x=object[4]
		ret.y=object[5]
		ret.z=object[6]
		if myHero.name == 'Katarina' and ret.charName~=nil and (ret.charName == 'Katarina_deathLotus_cas.troy' or ret.charName == 'Katarina_deathLotus_empty.troy') and GetDistance(ret)==0 then locus = false end
		if myHero.name == 'Janna' and ret.charName~=nil and ret.charName == 'ReapTheWhirlwind_green_cas.troy' and GetDistance(ret)==0 then locus = false end
		if myHero.name == 'Karthus' and ret.charName~=nil and ret.charName == 'Karthus_Base_R_Cas.troy' and GetDistance(ret)==0 then locus = false end
	end
end
 
function OnCreateObj(obj)
	if obj~=nil then
		if myHero.name=='Katarina' then
			if obj.charName == 'Katarina_deathLotus_empty.troy' and GetDistance(obj)==0 then locus = false end
		end
		if myHero.name=='Janna' then
			if obj.charName == 'ReapTheWhirlwind_green_cas.troy' and GetDistance(obj)==0 then locus = true end
		end
		if myHero.name=='Karthus' then
			if obj.charName == 'Karthus_Base_R_Cas.troy' and GetDistance(obj)==0 then locus = true end
		end
	end
end

function OnProcessSpell(unit,spell)
	if unit ~= nil and spell ~= nil and unit.charName == myHero.charName then
		if spell.name == 'KatarinaR' then 
			locus = true 
			Katarina_Timer = GetTickCount()
		end
		if spell.name == 'Crowstorm' then 
			locus = true 
			Fiddle_Timer = GetTickCount()
		end
		if spell.name == 'ReapTheWhirlwind' then 
			locus = true
			Janna_Timer = GetTickCount()
		end
		if spell.name == 'KarthusFallenOne' then 
			locus = true
			Karthus_Timer = GetTickCount()
		end
	end
	--------------------------------------------------------------------------
	local P1 = spell.startPos
	local P2 = spell.endPos
	local calc = (math.floor(math.sqrt((P2.x-unit.x)^2 + (P2.z-unit.z)^2)))
	if string.find(unit.name,'Minion_') == nil and string.find(unit.name,'Turret_') == nil then
		if (unit.team ~= myHero.team or (show_allies==1)) and string.find(spell.name,'Basic') == nil then
			for i=1, #skillshotArray, 1 do
				local maxdist
				local dodgeradius
				dodgeradius = math.max(skillshotArray[i].radius,100)+add_move_range
				maxdist = skillshotArray[i].maxdistance+150
				if spell.name == skillshotArray[i].name then
					skillshotArray[i].shot = 1
					skillshotArray[i].lastshot = os.clock()
					if skillshotArray[i].type == 1 then
						maxdist = skillshotArray[i].maxdistance+150
						skillshotArray[i].p1x = unit.x
						skillshotArray[i].p1y = unit.y
						skillshotArray[i].p1z = unit.z
						skillshotArray[i].p2x = unit.x + (maxdist)/calc*(P2.x-unit.x)
						skillshotArray[i].p2y = P2.y
						skillshotArray[i].p2z = unit.z + (maxdist)/calc*(P2.z-unit.z)
						dodgelinepass(unit, P2, dodgeradius, maxdist)
					elseif skillshotArray[i].type == 2 then
						skillshotArray[i].px = P2.x
						skillshotArray[i].py = P2.y
						skillshotArray[i].pz = P2.z
						dodgelinepoint(unit, P2, dodgeradius)
					elseif skillshotArray[i].type == 3 then
						skillshotArray[i].skillshotpoint = calculateLineaoe(unit, P2, maxdist)
						if skillshotArray[i].name ~= 'SummonerClairvoyance' then
							dodgeaoe(unit, P2, dodgeradius)
						end
					elseif skillshotArray[i].type == 4 then
						skillshotArray[i].px = unit.x + (maxdist)/calc*(P2.x-unit.x)
						skillshotArray[i].py = P2.y
						skillshotArray[i].pz = unit.z + (maxdist)/calc*(P2.z-unit.z)
						dodgelinepass(unit, P2, dodgeradius, maxdist)
					elseif skillshotArray[i].type == 5 then
						maxdist = skillshotArray[i].maxdistance
						skillshotArray[i].skillshotpoint = calculateLineaoe2(unit, P2, maxdist)
						dodgeaoe(unit, P2, dodgeradius)
					end
				end
			end
		end
	end
end

function dodgeaoe(pos1, pos2, radius)
	local calc = (math.floor(math.sqrt((pos2.x-myHero.x)^2 + (pos2.z-myHero.z)^2)))
	local dodgex
	local dodgez
	dodgex = pos2.x + (radius/calc)*(myHero.x-pos2.x)
	dodgez = pos2.z + (radius/calc)*(myHero.z-pos2.z)
	if calc < radius and DodgeConfig.DodgeSkillShotsAOE and not locus then
		if DodgeConfig.Block_User_Input and GetCursorX() > xa and GetCursorX() < xb and GetCursorY() > ya and GetCursorY() < yb then send.block_input(true,DodgeConfig.Block_Time,MakeStateMatch) end
		block_timer = GetClock()
		MoveToXYZ(dodgex,0,dodgez)
	end
end

function dodgelinepoint(pos1, pos2, radius)
	local calc1 = (math.floor(math.sqrt((pos2.x-myHero.x)^2 + (pos2.z-myHero.z)^2)))
	local calc2 = (math.floor(math.sqrt((pos1.x-myHero.x)^2 + (pos1.z-myHero.z)^2)))
	local calc4 = (math.floor(math.sqrt((pos1.x-pos2.x)^2 + (pos1.z-pos2.z)^2)))
	local calc3
	local perpendicular
	local k
	local x4
	local z4
	local dodgex
	local dodgez
	perpendicular = (math.floor((math.abs((pos2.x-pos1.x)*(pos1.z-myHero.z)-(pos1.x-myHero.x)*(pos2.z-pos1.z)))/(math.sqrt((pos2.x-pos1.x)^2 + (pos2.z-pos1.z)^2))))
	k = ((pos2.z-pos1.z)*(myHero.x-pos1.x) - (pos2.x-pos1.x)*(myHero.z-pos1.z)) / ((pos2.z-pos1.z)^2 + (pos2.x-pos1.x)^2)
	x4 = myHero.x - k * (pos2.z-pos1.z)
	z4 = myHero.z + k * (pos2.x-pos1.x)
	calc3 = (math.floor(math.sqrt((x4-myHero.x)^2 + (z4-myHero.z)^2)))
	dodgex = x4 + (radius/calc3)*(myHero.x-x4)
	dodgez = z4 + (radius/calc3)*(myHero.z-z4)
	if perpendicular < radius and calc1 < calc4 and calc2 < calc4 and DodgeConfig.DodgeSkillShots and not locus then
		if DodgeConfig.Block_User_Input and GetCursorX() > xa and GetCursorX() < xb and GetCursorY() > ya and GetCursorY() < yb then send.block_input(true,DodgeConfig.Block_Time,MakeStateMatch) end
		block_timer = GetClock()
		MoveToXYZ(dodgex,0,dodgez)
	end
end

function dodgelinepass(pos1, pos2, radius, maxDist)
	local pm2x = pos1.x + (maxDist)/(math.floor(math.sqrt((pos1.x-pos2.x)^2 + (pos1.z-pos2.z)^2)))*(pos2.x-pos1.x)
	local pm2z = pos1.z + (maxDist)/(math.floor(math.sqrt((pos1.x-pos2.x)^2 + (pos1.z-pos2.z)^2)))*(pos2.z-pos1.z)
	local calc1 = (math.floor(math.sqrt((pm2x-myHero.x)^2 + (pm2z-myHero.z)^2)))
	local calc2 = (math.floor(math.sqrt((pos1.x-myHero.x)^2 + (pos1.z-myHero.z)^2)))
	local calc3
	local calc4 = (math.floor(math.sqrt((pos1.x-pm2x)^2 + (pos1.z-pm2z)^2)))
	local perpendicular
	local k
	local x4
	local z4
	local dodgex
	local dodgez
	perpendicular = (math.floor((math.abs((pm2x-pos1.x)*(pos1.z-myHero.z)-(pos1.x-myHero.x)*(pm2z-pos1.z)))/(math.sqrt((pm2x-pos1.x)^2 + (pm2z-pos1.z)^2))))
	k = ((pm2z-pos1.z)*(myHero.x-pos1.x) - (pm2x-pos1.x)*(myHero.z-pos1.z)) / ((pm2z-pos1.z)^2 + (pm2x-pos1.x)^2)
	x4 = myHero.x - k * (pm2z-pos1.z)
	z4 = myHero.z + k * (pm2x-pos1.x)
	calc3 = (math.floor(math.sqrt((x4-myHero.x)^2 + (z4-myHero.z)^2)))
	dodgex = x4 + (radius/calc3)*(myHero.x-x4)
	dodgez = z4 + (radius/calc3)*(myHero.z-z4)
	if perpendicular < radius and calc1 < calc4 and calc2 < calc4 and DodgeConfig.DodgeSkillShots and not locus then
		if DodgeConfig.Block_User_Input and GetCursorX() > xa and GetCursorX() < xb and GetCursorY() > ya and GetCursorY() < yb then send.block_input(true,DodgeConfig.Block_Time,MakeStateMatch) end
		block_timer = GetClock()
		MoveToXYZ(dodgex,0,dodgez)
	end
end


function calculateLinepass(pos1, pos2, spacing, maxDist)
	local calc = (math.floor(math.sqrt((pos2.x-pos1.x)^2 + (pos2.z-pos1.z)^2)))
	local line = {}
	local point1 = {}
	point1.x = pos1.x
	point1.y = pos1.y
	point1.z = pos1.z
	local point2 = {}
	point1.x = pos1.x + (maxDist)/calc*(pos2.x-pos1.x)
	point1.y = pos2.y
	point1.z = pos1.z + (maxDist)/calc*(pos2.z-pos1.z)
	table.insert(line, point2)
	table.insert(line, point1)
	return line
end

function calculateLineaoe(pos1, pos2, maxDist)
	local line = {}
	local point = {}
	point.x = pos2.x
	point.y = pos2.y
	point.z = pos2.z
	table.insert(line, point)
	return line
end

function calculateLineaoe2(pos1, pos2, maxDist)
	local calc = (math.floor(math.sqrt((pos2.x-pos1.x)^2 + (pos2.z-pos1.z)^2)))
	local line = {}
	local point = {}
		if calc < maxDist then
		point.x = pos2.x
		point.y = pos2.y
		point.z = pos2.z
		table.insert(line, point)
	else
		point.x = pos1.x + maxDist/calc*(pos2.x-pos1.x)
		point.z = pos1.z + maxDist/calc*(pos2.z-pos1.z)
		point.y = pos2.y
		table.insert(line, point)
	end
	return line
end

function calculateLinepoint(pos1, pos2, spacing, maxDist)
	local line = {}
	local point1 = {}
	point1.x = pos1.x
	point1.y = pos1.y
	point1.z = pos1.z
	local point2 = {}
	point1.x = pos2.x
	point1.y = pos2.y
	point1.z = pos2.z
	table.insert(line, point2)
	table.insert(line, point1)
	return line
end

function Skillshots()
	cc=cc+1
	if (cc==150) then
		LoadTable()
	end
	if (cc>150) then
		DrawText('Dodge ready',70,150,Color.White)
	end
	if DodgeConfig.DrawSkillShots then
		for i=1, #skillshotArray, 1 do
			if skillshotArray[i].shot == 1 then
				local radius = skillshotArray[i].radius
				local color = skillshotArray[i].color
				if skillshotArray[i].isline == false then
					for number, point in pairs(skillshotArray[i].skillshotpoint) do
						DrawCircle(point.x, point.y, point.z, radius, color)
					end
				else
					startVector = Vector(skillshotArray[i].p1x,skillshotArray[i].p1y,skillshotArray[i].p1z)
					endVector = Vector(skillshotArray[i].p2x,skillshotArray[i].p2y,skillshotArray[i].p2z)
					directionVector = (endVector-startVector):normalized()
					local angle=0
					if (math.abs(directionVector.x)<.00001) then
						if directionVector.z > 0 then angle=90
						elseif directionVector.z < 0 then angle=270
						else angle=0
						end
					else
						local theta = math.deg(math.atan(directionVector.z / directionVector.x))
						if directionVector.x < 0 then theta = theta + 180 end
							if theta < 0 then theta = theta + 360 end
								angle=theta
							end
								angle=((90-angle)*2*math.pi)/360
								DrawLine(startVector.x, startVector.y, startVector.z, GetDistance(startVector, endVector)+170, 1,angle,radius)
						end
					end
				end
			end
	for i=1, #skillshotArray, 1 do
		if os.clock() > (skillshotArray[i].lastshot + skillshotArray[i].time) then
		skillshotArray[i].shot = 0
		end
	end
end

function LoadTable()
	print("table loaded::")
	for i = 1, objManager:GetMaxHeroes() do
		local ee = objManager:GetHero(i)
		if ee~=nil and ee.team~=myHero.team then
			if ee.name == 'Aatrox' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=600,type=3,radius=200,color=coloryellow,time=1,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name=ee.SpellNameE,shot=0,lastshot=0,skillshotpoint={},maxdistance=1000,type=1,radius=120,color=colorcyan,time=1,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Ahri' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=880,type=1,radius=105,color=colorcyan,time=((880/1.7)+260)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name=ee.SpellNameE,shot=0,lastshot=0,skillshotpoint={},maxdistance=975,type=1,radius=70,color=colorcyan,time=((975/1.5)+260)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Amumu' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=1100,type=1,radius=90,color=colorcyan,time=((1100/2)+260)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Anivia' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=1100,type=1,radius=90,color=colorcyan,time=2,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Ashe' then
				table.insert(skillshotArray,{name=ee.SpellNameR,shot=0,lastshot=0,skillshotpoint={},maxdistance=10000,type=1,radius=120,color=colorcyan,time=4,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Blitzcrank' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=925,type=1,radius=80,color=colorcyan,time=((925/1.7)+260)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Brand' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=1050,type=1,radius=85,color=colorcyan,time=((1050/1.6)+260)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name=ee.SpellNameW,shot=0,lastshot=0,skillshotpoint={},maxdistance=900,type=3,radius=250,color=coloryellow,time=1,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Braum' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=1000,type=1,radius=100,color=colorcyan,time=1,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Cassiopeia' then
				table.insert(skillshotArray,{name=ee.SpellNameW,shot=0,lastshot=0,skillshotpoint={},maxdistance=850,type=3,radius=175,color=coloryellow,time=1,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=850,type=3,radius=75,color=coloryellow,time=1,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Caitlyn' then -- need width + speed
				--table.insert(skillshotArray,{name='CaitlynEntrapmentMissile',shot=0,lastshot=0,skillshotpoint={},maxdistance=1000,type=1,radius=50,color=colorcyan,time=1,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=1300,type=1,radius=150,color=colorcyan,time=1,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Chogath' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=950,type=3,radius=275,color=coloryellow,time=1.5,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Corki' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=800,type=2,radius=150,color=colorcyan,time=1,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name=ee.SpellNameR,shot=0,lastshot=0,skillshotpoint={},maxdistance=1225,type=1,radius=50,color=colorcyan,time=((1225/2)+260)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Diana' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=900,type=1,radius=205,color=colorcyan,time=((830/1.4)+260)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'DrMundo' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=1000,type=1,radius=80,color=colorcyan,time=((1000/2)+160)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			
			end
			if ee.name == 'Draven' then
				table.insert(skillshotArray,{name=ee.SpellNameE,shot=0,lastshot=0,skillshotpoint={},maxdistance=1050,type=1,radius=135,color=colorcyan,time=((1050/1.4)+260)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name=ee.SpellNameR,shot=0,lastshot=0,skillshotpoint={},maxdistance=5000,type=1,radius=125,color=colorcyan,time=4,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Elise' then
				table.insert(skillshotArray,{name='EliseHumanE',shot=0,lastshot=0,skillshotpoint={},maxdistance=1075,type=1,radius=80,color=colorcyan,time=((1075/1.5)+260)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Ezreal' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=1100,type=1,radius=100,color=colorcyan,time=((1100/2)+260)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name='EzrealEssenceFluxMissile',shot=0,lastshot=0,skillshotpoint={},maxdistance=900,type=1,radius=100,color=colorcyan,time=((900/1.5)+260)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name=ee.SpellNameR,shot=0,lastshot=0,skillshotpoint={},maxdistance=10000,type=1,radius=175,color=colorcyan,time=4,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Fizz' then
				table.insert(skillshotArray,{name=ee.SpellNameE,shot=0,lastshot=0,skillshotpoint={},maxdistance=400,type=3,radius=270,color=coloryellow,time=0.5,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name=ee.SpellNameR,shot=0,lastshot=0,skillshotpoint={},maxdistance=1275,type=2,radius=100,color=colorcyan,time=((1275/1.3)+260)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'FiddleSticks' then
				table.insert(skillshotArray,{name=ee.SpellNameR,shot=0,lastshot=0,skillshotpoint={},maxdistance=800,type=3,radius=600,color=coloryellow,time=1.5,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Galio' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=905,type=3,radius=200,color=coloryellow,time=1.5,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name=ee.SpellNameE,shot=0,lastshot=0,skillshotpoint={},maxdistance=1000,type=1,radius=120,color=colorcyan,time=1.5,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Gnar' then
				table.insert(skillshotArray,{name='gnarqmissile',shot=0,lastshot=0,skillshotpoint={},maxdistance=1100,type=1,radius=90,color=coloryellow,time=1,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name='GnarBigQMissile',shot=0,lastshot=0,skillshotpoint={},maxdistance=1100,type=1,radius=90,color=coloryellow,time=1,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name='gnarbige',shot=0,lastshot=0,skillshotpoint={},maxdistance=475,type=3,radius=160,color=coloryellow,time=0.8,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Gragas' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=1100,type=3,radius=320,color=coloryellow,time=2.5,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name=ee.SpellNameE,shot=0,lastshot=0,skillshotpoint={},maxdistance=650,type=2,radius=60,color=colorcyan,time=1.5,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name=ee.SpellNameR,shot=0,lastshot=0,skillshotpoint={},maxdistance=1050,type=3,radius=400,color=coloryellow,time=1.5,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Graves' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=1000,type=1,radius=110,color=colorcyan,time=1,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name=ee.SpellNameR,shot=0,lastshot=0,skillshotpoint={},maxdistance=1000,type=1,radius=100,color=colorcyan,time=1,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Heimerdinger' then
				table.insert(skillshotArray,{name=ee.SpellNameW,shot=0,lastshot=0,skillshotpoint={},maxdistance=1100,type=1,radius=100,color=colorcyan,time=((1100/1.4)+260)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name=ee.SpellNameE,shot=0,lastshot=0,skillshotpoint={},maxdistance=950,type=3,radius=180,color=coloryellow,time=1,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name='heimerdingereult',shot=0,lastshot=0,skillshotpoint={},maxdistance=950,type=3,radius=180,color=coloryellow,time=1,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})		
			end
			if ee.name == 'Irelia' then
				--table.insert(skillshotArray,{name=ee.SpellNameR,shot=0,lastshot=0,skillshotpoint={},maxdistance=1200,type=1,radius=150,color=colorcyan,time=0.8,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Janna' then
				table.insert(skillshotArray,{name='HowlingGale',shot=0,lastshot=0,skillshotpoint={},maxdistance=1700,type=1,radius=215,color=colorcyan,time=((1700/.9)+260)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'JarvanIV' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=770,type=1,radius=70,color=colorcyan,time=1,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name=ee.SpellNameE,shot=0,lastshot=0,skillshotpoint={},maxdistance=830,type=3,radius=150,color=coloryellow,time=2,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Jayce' then
				table.insert(skillshotArray,{name='jayceshockblast',shot=0,lastshot=0,skillshotpoint={},maxdistance=1470,type=1,radius=100,color=colorcyan,time=1,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Jinx' then
				table.insert(skillshotArray,{name=ee.SpellNameW,shot=0,lastshot=0,skillshotpoint={},maxdistance=1500,type=1,radius=70,color=colorcyan,time=((1500/3.3)+600)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name=ee.SpellNameR,shot=0,lastshot=0,skillshotpoint={},maxdistance=10000,type=1,radius=145,color=colorcyan,time=4,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Kalista' then
				table.insert(skillshotArray,{name="kalistamysticshotmis",shot=0,lastshot=0,skillshotpoint={},maxdistance=950,type=1,radius=50,color=colorcyan,time=((1450/2.3)+260)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Karma' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=950,type=1,radius=100,color=colorcyan,time=((950/1.7)+260)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Karthus' then
				table.insert(skillshotArray,{name='karthuslaywastea2',shot=0,lastshot=0,skillshotpoint={},maxdistance=875,type=3,radius=165,color=coloryellow,time=1,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Kennen' then
				table.insert(skillshotArray,{name='KennenShurikenHurlMissile1',shot=0,lastshot=0,skillshotpoint={},maxdistance=1050,type=1,radius=60,color=colorcyan,time=((1050/1.6)+160)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Khazix' then
				table.insert(skillshotArray,{name='KhazixW',shot=0,lastshot=0,skillshotpoint={},maxdistance=1000,type=1,radius=70,color=coloryellow,time=((1000/1.7)+260)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name='KhazixE',shot=0,lastshot=0,skillshotpoint={},maxdistance=600,type=3,radius=250,color=coloryellow,time=0.5,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name='khazixelong',shot=0,lastshot=0,skillshotpoint={},maxdistance=900,type=3,radius=250,color=coloryellow,time=1.2,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'KogMaw' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=1000,type=1,radius=80,color=colorcyan,time=((1000/1.6)+260)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})			
				table.insert(skillshotArray,{name=ee.SpellNameE,shot=0,lastshot=0,skillshotpoint={},maxdistance=1280,type=1,radius=130,color=colorcyan,time=((1280/1.4)+260)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name=ee.SpellNameR,shot=0,lastshot=0,skillshotpoint={},maxdistance=1800,type=3,radius=230,color=coloryellow,time=1.5,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Leblanc' then
				table.insert(skillshotArray,{name='LeblancSlide',shot=0,lastshot=0,skillshotpoint={},maxdistance=600,type=3,radius=250,color=coloryellow,time=0.5,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name='LeblancSlideM',shot=0,lastshot=0,skillshotpoint={},maxdistance=600,type=3,radius=250,color=coloryellow,time=0.5,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name=ee.SpellNameE,shot=0,lastshot=0,skillshotpoint={},maxdistance=950,type=1,radius=80,color=colorcyan,time=((950/1.6)+260)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'LeeSin' then
				table.insert(skillshotArray,{name='BlindMonkQOne',shot=0,lastshot=0,skillshotpoint={},maxdistance=975,type=1,radius=70,color=colorcyan,time=((975/1.8)+260)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Leona' then -- Don't ownt his champ
				table.insert(skillshotArray,{name=ee.SpellNameE,shot=0,lastshot=0,skillshotpoint={},maxdistance=700,type=1,radius=120,color=colorcyan,time=1,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name=ee.SpellNameR,shot=0,lastshot=0,skillshotpoint={},maxdistance=1200,type=3,radius=250,color=coloryellow,time=1,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Lissandra' then -- Don't own this champ
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=725,type=1,radius=100,color=coloryellow,time=1,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name=ee.SpellNameE,shot=0,lastshot=0,skillshotpoint={},maxdistance=1050,type=1,radius=100,color=coloryellow,time=1.5,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Lucian' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=1110,type=1,radius=70,color=colorcyan,time=.5,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name=ee.SpellNameE,shot=0,lastshot=0,skillshotpoint={},maxdistance=1000,type=1,radius=90,color=colorcyan,time=((1000/1.6)+260)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Lux' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=1175,type=1,radius=90,color=colorcyan,time=((1175/1.2)+260)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name=ee.SpellNameE,shot=0,lastshot=0,skillshotpoint={},maxdistance=1100,type=3,radius=285,color=coloryellow,time=2.5,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name=ee.SpellNameR,shot=0,lastshot=0,skillshotpoint={},maxdistance=3340,type=1,radius=150,color=colorcyan,time=1.5,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Lulu' then -- Don't own this champ
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=925,type=1,radius=50,color=colorcyan,time=1,isline=true,px=0,py=0,pz=0,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Maokai' then -- Don't own this champ
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=600,type=1,radius=100,color=colorcyan,time=1,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Malzahar' then
				table.insert(skillshotArray,{name=ee.SpellNameW,shot=0,lastshot=0,skillshotpoint={},maxdistance=800,type=3,radius=250,color=coloryellow,time=1,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'MissFortune' then
				table.insert(skillshotArray,{name='MissFortuneScattershot',shot=0,lastshot=0,skillshotpoint={},maxdistance=800,type=3,radius=400,color=coloryellow,time=1,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Morgana' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=1175,type=1,radius=80,color=colorcyan,time=((1175/1.2)+260)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name=ee.SpellNameW,shot=0,lastshot=0,skillshotpoint={},maxdistance=900,type=3,radius=295,color=coloryellow,time=1.5,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Nami' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=875,type=3,radius=210,color=coloryellow,time=1,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name=ee.SpellNameR,shot=0,lastshot=0,skillshotpoint={},maxdistance=2550,type=1,radius=350,color=colorcyan,time=3,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Nautilus' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=950,type=1,radius=100,color=colorcyan,time=1.5,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Nidalee' then
				table.insert(skillshotArray,{name='JavelinToss',shot=0,lastshot=0,skillshotpoint={},maxdistance=1500,type=1,radius=30,color=colorcyan,time=((1500/1.3)+260)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Nocturne' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=1200,type=1,radius=70,color=colorcyan,time=((1200/1.4)+260)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Olaf' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=1000,type=2,radius=100,color=colorcyan,time=((1000/1.6)+260)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Orianna' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=825,type=3,radius=150,color=coloryellow,time=1.5,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Quinn' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=1025,type=1,radius=40,color=coloryellow,time=((1025/1.6)+260)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Renekton' then
				table.insert(skillshotArray,{name='RenektonSliceAndDice',shot=0,lastshot=0,skillshotpoint={},maxdistance=450,type=1,radius=150,color=colorcyan,time=1,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name='renektondice',shot=0,lastshot=0,skillshotpoint={},maxdistance=450,type=1,radius=150,color=colorcyan,time=1,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Rengar' then
				table.insert(skillshotArray,{name=ee.SpellNameE,shot=0,lastshot=0,skillshotpoint={},maxdistance=1000,type=1,radius=80,color=coloryellow,time=((1000/1.5)+260)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Rumble' then
				table.insert(skillshotArray,{name=ee.SpellNameE,shot=0,lastshot=0,skillshotpoint={},maxdistance=850,type=1,radius=100,color=colorcyan,time=((850/2)+260)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Sejuani' then
				table.insert(skillshotArray,{name=ee.SpellNameR,shot=0,lastshot=0,skillshotpoint={},maxdistance=1150,type=1,radius=125,color=colorcyan,time=1,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Sivir' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=1075,type=1,radius=100,color=colorcyan,time=((1075/1.3)+260)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Shen' then
				table.insert(skillshotArray,{name=ee.SpellNameE,shot=0,lastshot=0,skillshotpoint={},maxdistance=600,type=2,radius=150,color=colorcyan,time=1,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Shyvana' then -- Don't own this champ
				table.insert(skillshotArray,{name='ShyvanaTransformLeap',shot=0,lastshot=0,skillshotpoint={},maxdistance=925,type=1,radius=150,color=colorcyan,time=1.5,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name='ShyvanaFireballMissile',shot=0,lastshot=0,skillshotpoint={},maxdistance=1000,type=1,radius=150,color=colorcyan,time=1,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Skarner' then -- Don't own this champ
				table.insert(skillshotArray,{name=ee.SpellNameE,shot=0,lastshot=0,skillshotpoint={},maxdistance=600,type=1,radius=100,color=colorcyan,time=1,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Sona' then
				table.insert(skillshotArray,{name=ee.SpellNameR,shot=0,lastshot=0,skillshotpoint={},maxdistance=1000,type=1,radius=150,color=colorcyan,time=1,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Soraka' then
				table.insert(skillshotArray,{name=ee.SpellNameE,shot=0,lastshot=0,skillshotpoint={},maxdistance=925,type=3,radius=290,color=coloryellow,time=2,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=950,type=3,radius=260,color=coloryellow,time=1,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Syndra' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=800,type=3,radius=150,color=colorcyan,time=2,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name='syndrawcast',shot=0,lastshot=0,skillshotpoint={},maxdistance=950,type=3,radius=150,color=colorcyan,time=1,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Swain' then
				table.insert(skillshotArray,{name=ee.SpellNameW,shot=0,lastshot=0,skillshotpoint={},maxdistance=900,type=3,radius=265,color=coloryellow,time=1.5,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Thresh' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=1100,type=1,radius=100,color=coloryellow,time=1.5,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name=ee.SpellNameE,shot=0,lastshot=0,skillshotpoint={},maxdistance=400,type=1,radius=300,color=coloryellow,time=0.5,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Tryndamere' then
				table.insert(skillshotArray,{name='Slash',shot=0,lastshot=0,skillshotpoint={},maxdistance=600,type=2,radius=100,color=colorcyan,time=1,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Tristana' then
				table.insert(skillshotArray,{name=ee.SpellNameW,shot=0,lastshot=0,skillshotpoint={},maxdistance=900,type=3,radius=200,color=coloryellow,time=1,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'TwistedFate' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=1450,type=1,radius=80,color=colorcyan,time=5,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Urgot' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=1000,type=1,radius=80,color=colorcyan,time=0.8,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name=ee.SpellNameE,shot=0,lastshot=0,skillshotpoint={},maxdistance=950,type=3,radius=300,color=coloryellow,time=1,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Varus' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=1475,type=1,radius=50,color=coloryellow,time=1})
				table.insert(skillshotArray,{name=ee.SpellNameR,shot=0,lastshot=0,skillshotpoint={},maxdistance=1075,type=1,radius=125,color=colorcyan,time=1.5,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Veigar' then
				table.insert(skillshotArray,{name=ee.SpellNameE,shot=0,lastshot=0,skillshotpoint={},maxdistance=900,type=3,radius=225,color=coloryellow,time=2,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name=ee.SpellNameW,shot=0,lastshot=0,skillshotpoint={},maxdistance=900,type=3,radius=200,color=coloryellow,time=1.5,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Vi' then
				table.insert(skillshotArray,{name='ViQ',shot=0,lastshot=0,skillshotpoint={},maxdistance=900,type=1,radius=150,color=coloryellow,time=1,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Viktor' then
				--table.insert(skillshotArray,{name='ViktorDeathRay',shot=0,lastshot=0,skillshotpoint={},maxdistance=700,type=1,radius=150,color=coloryellow,time=2})
			end
			if ee.name == 'Velkoz' then
				table.insert(skillshotArray,{name='VelkozQ',shot=0,lastshot=0,skillshotpoint={},maxdistance=1050,type=1,radius=90,color=coloryellow,time=2,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name='VelkozW',shot=0,lastshot=0,skillshotpoint={},maxdistance=1050,type=1,radius=130,color=coloryellow,time=2,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name='VelkozE',shot=0,lastshot=0,skillshotpoint={},maxdistance=850,type=3,radius=200,color=coloryellow,time=1.2,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Xerath' then
				table.insert(skillshotArray,{name='xeratharcanopulse2',shot=0,lastshot=0,skillshotpoint={},maxdistance=1400,type=1,radius=100,color=colorcyan,time=1,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name='XerathMageSpear',shot=0,lastshot=0,skillshotpoint={},maxdistance=1050,type=1,radius=80,color=colorcyan,time=((1050/1.4)+260)/1000,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name='XeratharcaneBarrage2',shot=0,lastshot=0,skillshotpoint={},maxdistance=1100,type=3,radius=260,color=coloryellow,time=1.5,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name='xerathrmissilewrapper',shot=0,lastshot=0,skillshotpoint={},maxdistance=5600,type=3,radius=210,color=coloryellow,time=1,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Yasuo' then
				table.insert(skillshotArray,{name='yasuoq3',shot=0,lastshot=0,skillshotpoint={},maxdistance=900,type=1,radius=110,color=coloryellow,time=1,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Zac' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=550,type=1,radius=100,color=coloryellow,time=1,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name=ee.SpellNameE,shot=0,lastshot=0,skillshotpoint={},maxdistance=1550,type=3,radius=200,color=colorcyan,time=2,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Zed' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=900,type=1,radius=100,color=coloryellow,time=1,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Ziggs' then
				table.insert(skillshotArray,{name='ZiggsQ',shot=0,lastshot=0,skillshotpoint={},maxdistance=850,type=1,radius=100,color=coloryellow,time=1.5,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name='ZiggsW',shot=0,lastshot=0,skillshotpoint={},maxdistance=1000,type=3,radius=225,color=coloryellow,time=1,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name='ZiggsR',shot=0,lastshot=0,skillshotpoint={},maxdistance=5300,type=3,radius=550,color=coloryellow,time=3,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
			if ee.name == 'Zyra' then
				table.insert(skillshotArray,{name=ee.SpellNameQ,shot=0,lastshot=0,skillshotpoint={},maxdistance=800,type=3,radius=250,color=coloryellow,time=1,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name=ee.SpellNameE,shot=0,lastshot=0,skillshotpoint={},maxdistance=1100,type=1,radius=100,color=colorcyan,time=1.5,isline=true,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
				table.insert(skillshotArray,{name=ee.SpellNameR,shot=0,lastshot=0,skillshotpoint={},maxdistance=700,type=3,radius=550,color=coloryellow,time=2,isline=false,p1x=0,p1y=0,p1z=0,p2x=0,p2y=0,p2z=0})
			end
		end
	end
end

function CountEnemyHeroInRange(range, object)
	object = object or myHero
	range = range and range * range or myHero.range * myHero.range
	local enemyInRange = 0
	for i = 1, objManager:GetMaxHeroes() do
	local hero = objManager:GetHero(i)
	if (hero~=nil and hero.team~=myHero.team and hero.dead==0) and GetDistance(object, hero) <= range then
	enemyInRange = enemyInRange + 1
	end
	end
	return enemyInRange
end

SetTimerCallback('Main')