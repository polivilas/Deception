if SERVER then
	AddCSLuaFile("shared.lua")
end

if CLIENT then
    SWEP.AcogGlass = Material( "models/wystan/attachments/acog/lense" )
    SWEP.AcogRT = GetRenderTarget( "acog_glass_rt", 512, 512, false )
    SWEP.AcogGlass:SetTexture( "$basetexture", SWEP.AcogRT )
end

function SWEP:Initialize()
 
    // other initialize code goes here
 
    if CLIENT then
     
        self:CreateModels(self.VElements) // create viewmodels
        self:CreateModels(self.WElements) // create worldmodels
         
        // init view model bone build function
        self.BuildViewModelBones = function( s )
            if LocalPlayer():GetActiveWeapon() == self and self.ViewModelBoneMods then
                for k, v in pairs( self.ViewModelBoneMods ) do
                    local bone = s:LookupBone(k)
                    if (!bone) then continue end
                    local m = s:GetBoneMatrix(bone)
                    if (!m) then continue end
                    m:Scale(v.scale)
                    m:Rotate(v.angle)
                    m:Translate(v.pos)
                    s:SetBoneMatrix(bone, m)
                end
            end
        end
         
    end
 
end
 
 
function SWEP:OnRemove()
     
    // other onremove code goes here
     
    if CLIENT then
        self:RemoveModels()
    end
     
end
     
 
if CLIENT then
	local Laser = Material("effects/redlaser1")
	local LaserDot = Material("effects/brightglow_y")
 
    SWEP.vRenderOrder = nil
    function SWEP:ViewModelDrawn()
         
        local vm = self.Owner:GetViewModel()
        if !IsValid(vm) then return end
         
        if (!self.VElements) then return end
         
        if vm.BuildBonePositions ~= self.BuildViewModelBones then
            vm.BuildBonePositions = self.BuildViewModelBones
        end
 
        if (self.ShowViewModel == nil or self.ShowViewModel) then
            vm:SetColor(255,255,255,255)
        else
            // we set the alpha to 1 instead of 0 because else ViewModelDrawn stops being called
            vm:SetColor(255,255,255,1)
        end
         
        if (!self.vRenderOrder) then
             
            // we build a render order because sprites need to be drawn after models
            self.vRenderOrder = {}
 
            for k, v in pairs( self.VElements ) do
                if (v.type == "Model") then
                    table.insert(self.vRenderOrder, 1, k)
                elseif (v.type == "Sprite" or v.type == "Quad") then
                    table.insert(self.vRenderOrder, k)
                end
            end
             
        end
 
        for k, name in ipairs( self.vRenderOrder ) do
         
            local v = self.VElements[name]
            if (!v) then self.vRenderOrder = nil break end
         
            local model = v.modelEnt
            local sprite = v.spriteMaterial
             
            if (!v.bone) then continue end
             
            local pos, ang = self:GetBoneOrientation( self.VElements, v, vm )
             
            if (!pos) then continue end
             
            if (v.type == "Model" and IsValid(model)) then
 
                model:SetPos(pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z )
                ang:RotateAroundAxis(ang:Up(), v.angle.y)
                ang:RotateAroundAxis(ang:Right(), v.angle.p)
                ang:RotateAroundAxis(ang:Forward(), v.angle.r)
 
                model:SetAngles(ang)
                model:SetModelScale(v.size)
                 
                if (v.material == "") then
                    model:SetMaterial("")
                elseif (model:GetMaterial() != v.material) then
                    model:SetMaterial( v.material )
                end
                 
                if (v.skin and v.skin != model:GetSkin()) then
                    model:SetSkin(v.skin)
                end
                 
                if (v.bodygroup) then
                    for k, v in pairs( v.bodygroup ) do
                        if (model:GetBodygroup(k) != v) then
                            model:SetBodygroup(k, v)
                        end
                    end
                end
                 
                if (v.surpresslightning) then
                    render.SuppressEngineLighting(true)
                end
                 
                render.SetColorModulation(v.color.r/255, v.color.g/255, v.color.b/255)
                render.SetBlend(v.color.a/255)
                model:DrawModel()
                render.SetBlend(1)
                render.SetColorModulation(1, 1, 1)
                 
                if (v.surpresslightning) then
                    render.SuppressEngineLighting(false)
                end
                 
            elseif (v.type == "Sprite" and sprite) then
                 
                local drawpos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
                render.SetMaterial(sprite)
                render.DrawSprite(drawpos, v.size.x, v.size.y, v.color)
                 
            elseif (v.type == "Quad" and v.draw_func) then
                 
                local drawpos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
                ang:RotateAroundAxis(ang:Up(), v.angle.y)
                ang:RotateAroundAxis(ang:Right(), v.angle.p)
                ang:RotateAroundAxis(ang:Forward(), v.angle.r)
                 
                cam.Start3D2D(drawpos, ang, v.size)
                    v.draw_func( self )
                cam.End3D2D()
 
            end
             
        end
		
		if self.VElements and self.VElements["laser"] and self.VElements["laser"].color.a == 255 then
			local lt = self.LaserTune
			local fw = self.VElements["laser"].modelEnt:GetAngles()
			local pos = self.VElements["laser"].modelEnt:GetPos()
			local aim = self.Owner:EyeAngles()
			pos = pos + aim:Right() * lt.PosRight + aim:Up() * lt.PosUp + aim:Forward() * lt.PosForward
			fw:RotateAroundAxis(fw:Right(), lt.AngUp)
			fw:RotateAroundAxis(fw:Up(), lt.AngRight)
			fw:RotateAroundAxis(fw:Forward(), lt.AngForward)
			
			local dir = self:GetDTInt(3) != 1 and fw or (aim + self.Owner:GetPunchAngle())
			dir = dir:Forward()
			
			local td = {}
			td.start = pos
			td.endpos = td.start + dir * 8192
			td.filter = self.Owner
			
			local trace = util.TraceLine(td)
			
			render.SetMaterial(Laser)
			render.DrawBeam(pos + dir, trace.HitPos, 0.5, 0.5, 0.5, Color(255, 255, 255, 255))
			
			render.SetMaterial(LaserDot)
			render.DrawSprite(trace.HitPos, 2, 2, Color(255, 0, 0, 255))
		end
		
        local old
       
	   	if self.Weapon.VElements and self.Weapon.VElements["acog"] and self.Weapon.VElements["acog"].color.a == 255 and GetConVarNumber("cstm_oldacog") <= 0 then
			old = render.GetRenderTarget( )
			local ply = LocalPlayer()
			local ang = self.Weapon.VElements["acog"].modelEnt:GetAngles()
			local ang2 = ang - ply:EyeAngles()
			ang:RotateAroundAxis(ang:Up(), -ang2.y)
				
			local CamData = {}
			CamData.angles = ang
			CamData.origin = ply:GetShootPos()
			CamData.x = 0
			CamData.y = 0
			CamData.w = 512
			CamData.h = 512
			CamData.fov = 5
			CamData.drawviewmodel = false
			CamData.drawhud = false
			render.SetRenderTarget( self.AcogRT )
			render.SetViewPort( 0, 0, 512, 512 )
		
			cam.Start2D()
				render.RenderView(CamData)
			cam.End2D()
			
			render.SetViewPort( 0, 0, ScrW( ), ScrH( ) )
			render.SetRenderTarget( old )
		end
    end
 
    SWEP.wRenderOrder = nil
    function SWEP:DrawWorldModel()
		if self:GetDTInt(3) == 20 then
			self:DrawShadow(false)
			return
		else
			self:DrawShadow(true)
		end
         
        if (self.ShowWorldModel == nil or self.ShowWorldModel) then
            self:DrawModel()
			self:DrawShadow(false)
        end
         
        if (!self.WElements) then return end
         
        if (!self.wRenderOrder) then
 
            self.wRenderOrder = {}
 
            for k, v in pairs( self.WElements ) do
                if (v.type == "Model") then
                    table.insert(self.wRenderOrder, 1, k)
                elseif (v.type == "Sprite" or v.type == "Quad") then
                    table.insert(self.wRenderOrder, k)
                end
            end
 
        end
         
        if (IsValid(self.Owner)) then
            bone_ent = self.Owner
        else
            // when the weapon is dropped
            bone_ent = self
        end
         
        for k, name in pairs( self.wRenderOrder ) do
         
            local v = self.WElements[name]
            if (!v) then self.wRenderOrder = nil break end
             
            local pos, ang
             
            if (v.bone) then
                pos, ang = self:GetBoneOrientation( self.WElements, v, bone_ent )
            else
                pos, ang = self:GetBoneOrientation( self.WElements, v, bone_ent, "ValveBiped.Bip01_R_Hand" )
            end
             
            if (!pos) then continue end
             
            local model = v.modelEnt
            local sprite = v.spriteMaterial
             
            if (v.type == "Model" and IsValid(model)) then
 
                model:SetPos(pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z )
                ang:RotateAroundAxis(ang:Up(), v.angle.y)
                ang:RotateAroundAxis(ang:Right(), v.angle.p)
                ang:RotateAroundAxis(ang:Forward(), v.angle.r)
 
                model:SetAngles(ang)
                model:SetModelScale(v.size)
                 
                if (v.material == "") then
                    model:SetMaterial("")
                elseif (model:GetMaterial() != v.material) then
                    model:SetMaterial( v.material )
                end
                 
                if (v.skin and v.skin != model:GetSkin()) then
                    model:SetSkin(v.skin)
                end
                 
                if (v.bodygroup) then
                    for k, v in pairs( v.bodygroup ) do
                        if (model:GetBodygroup(k) != v) then
                            model:SetBodygroup(k, v)
                        end
                    end
                end
                 
                if (v.surpresslightning) then
                    render.SuppressEngineLighting(true)
                end
                 
                render.SetColorModulation(v.color.r/255, v.color.g/255, v.color.b/255)
                render.SetBlend(v.color.a/255)
                model:DrawModel()
                render.SetBlend(1)
                render.SetColorModulation(1, 1, 1)
                 
                if (v.surpresslightning) then
                    render.SuppressEngineLighting(false)
                end
                 
            elseif (v.type == "Sprite" and sprite) then
                 
                local drawpos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
                render.SetMaterial(sprite)
                render.DrawSprite(drawpos, v.size.x, v.size.y, v.color)
                 
            elseif (v.type == "Quad" and v.draw_func) then
                 
                local drawpos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
                ang:RotateAroundAxis(ang:Up(), v.angle.y)
                ang:RotateAroundAxis(ang:Right(), v.angle.p)
                ang:RotateAroundAxis(ang:Forward(), v.angle.r)
                 
                cam.Start3D2D(drawpos, ang, v.size)
                    v.draw_func( self )
                cam.End3D2D()
 
            end
             
        end
         
    end
 
    function SWEP:GetBoneOrientation( basetab, tab, ent, bone_override )
         
        local bone, pos, ang
        if (tab.rel and tab.rel != "") then
             
            local v = basetab[tab.rel]
             
            if (!v) then return end
             
            // Technically, if there exists an element with the same name as a bone
            // you can get in an infinite loop. Let's just hope nobody's that stupid.
            pos, ang = self:GetBoneOrientation( basetab, v, ent )
             
            if (!pos) then return end
             
            pos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
            ang:RotateAroundAxis(ang:Up(), v.angle.y)
            ang:RotateAroundAxis(ang:Right(), v.angle.p)
            ang:RotateAroundAxis(ang:Forward(), v.angle.r)
                 
        else
         
            bone = ent:LookupBone(bone_override or tab.bone)
 
            if (!bone) then return end
             
            pos, ang = Vector(0,0,0), Angle(0,0,0)
            local m = ent:GetBoneMatrix(bone)
            if (m) then
                pos, ang = m:GetTranslation(), m:GetAngles()
            end
             
            if (IsValid(self.Owner) and self.Owner:IsPlayer() and
                ent == self.Owner:GetViewModel() and self.ViewModelFlip) then
                ang.r = -ang.r // Fixes mirrored models
            end
         
        end
         
        return pos, ang
    end
 
    function SWEP:CreateModels( tab )
 
        if (!tab) then return end
 
        // Create the clientside models here because Garry says we can't do it in the render hook
        for k, v in pairs( tab ) do
            if (v.type == "Model" and v.model and v.model != "" and (!IsValid(v.modelEnt) or v.createdModel != v.model) and
                    string.find(v.model, ".mdl") and file.Exists ("models/cstrike/"..v.model,"GAME") ) then
                 
                v.modelEnt = ClientsideModel(v.model, RENDER_GROUP_VIEW_MODEL_OPAQUE)
                if (IsValid(v.modelEnt)) then
                    v.modelEnt:SetPos(self:GetPos())
                    v.modelEnt:SetAngles(self:GetAngles())
                    v.modelEnt:SetParent(self)
                    v.modelEnt:SetNoDraw(true)
                    v.createdModel = v.model
                else
                    v.modelEnt = nil
                end
                 
            elseif (v.type == "Sprite" and v.sprite and v.sprite != "" and (!v.spriteMaterial or v.createdSprite != v.sprite)
                and file.Exists ("materials/"..v.sprite..".vmt","GAME")) then
                 
                local name = v.sprite.."-"
                local params = { ["$basetexture"] = v.sprite }
                // make sure we create a unique name based on the selected options
                local tocheck = { "nocull", "additive", "vertexalpha", "vertexcolor", "ignorez" }
                for i, j in pairs( tocheck ) do
                    if (v[j]) then
                        params["$"..j] = 1
                        name = name.."1"
                    else
                        name = name.."0"
                    end
                end
 
                v.createdSprite = v.sprite
                v.spriteMaterial = CreateMaterial(name,"UnlitGeneric",params)
                 
            end
        end
         
    end
 
    function SWEP:OnRemove()
        self:RemoveModels()
    end
 
    function SWEP:RemoveModels()
        if (self.VElements) then
            for k, v in pairs( self.VElements ) do
                if (IsValid( v.modelEnt )) then v.modelEnt:Remove() end
            end
        end
        if (self.WElements) then
            for k, v in pairs( self.WElements ) do
                if (IsValid( v.modelEnt )) then v.modelEnt:Remove() end
            end
        end
        self.VElements = nil
        self.WElements = nil
    end
 
end