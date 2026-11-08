--!strict
-- Turns a generated mesh module (tools/carbody, src/shared/CarMeshes) into
-- MeshParts. Roblox cannot import a mesh from a script, so a car body made
-- in the repo ships as data: quantised vertex, normal, UV and triangle
-- buffers in base64. Each client decodes them into an EditableMesh and makes
-- one template MeshPart per mesh while any car shows it; every car clones the
-- template (MeshData.acquire / release).
--
-- EditableMesh does not replicate, which suits a body: it is visual only and
-- every client builds its own (BodyBuilder). In a published game it needs
-- the owner to be ID verified with "Enable Mesh / Image APIs" on in the
-- Creator Dashboard (RIG_SPEC.md section 7). Studio needs nothing.
local AssetService = game:GetService("AssetService")

local MeshData = {}

export type Piece = {
	triangleCount: number,
	sizeM: { number },
	offsetM: { number },
	counts: { number }, -- positions, normals, uvs
	positions: string,
	normals: string,
	uvs: string,
	triangles: string,
	-- Optional: uint8 RGB per position (sRGB), multiplied into the part's
	-- colour where drawn (measured in Studio 2026-09-28: vertex colours on an
	-- EditableMesh render on its MeshPart, on Metal and Foil too, and survive
	-- Clone and resizing). The garage's exhaust tips carry their dark bores
	-- and the titanium heat colours this way (tools/cosmetics).
	colors: string?,
}

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local DECODE: { [number]: number } = {}
for i = 1, #ALPHABET do
	DECODE[string.byte(ALPHABET, i)] = i - 1
end

function MeshData.base64(s: string): buffer
	local n = #s
	local padding = 0
	if string.sub(s, -2) == "==" then
		padding = 2
	elseif string.sub(s, -1) == "=" then
		padding = 1
	end
	local out = buffer.create(n // 4 * 3 - padding)
	local o = 0
	local size = buffer.len(out)
	for i = 1, n, 4 do
		local a, b, c, d = string.byte(s, i, i + 3)
		local v = bit32.lshift(DECODE[a], 18) + bit32.lshift(DECODE[b], 12) + bit32.lshift(DECODE[c] or 0, 6) + (DECODE[d] or 0)
		if o < size then
			buffer.writeu8(out, o, bit32.rshift(v, 16))
		end
		if o + 1 < size then
			buffer.writeu8(out, o + 1, bit32.band(bit32.rshift(v, 8), 255))
		end
		if o + 2 < size then
			buffer.writeu8(out, o + 2, bit32.band(v, 255))
		end
		o += 3
	end
	return out
end

-- Builds the EditableMesh in the piece's own space: metres, centred on its
-- bounding box.
function MeshData.editable(piece: Piece): EditableMesh
	local em = AssetService:CreateEditableMesh()
	assert(em, `[MeshData] {MeshData.BUDGET_ERROR}`)
	-- A client holds only 8 EditableMeshes (BEHAVIOURS.md): if filling this
	-- one fails (a bad buffer, an engine limit), destroy it before passing the
	-- error on, or its slot is gone for the session (garage round 3 final
	-- review M7).
	local ok, err = pcall(function()
		local nPos, nNrm, nUv = piece.counts[1], piece.counts[2], piece.counts[3]
		local hx, hy, hz = piece.sizeM[1] / 2, piece.sizeM[2] / 2, piece.sizeM[3] / 2
		local pos = MeshData.base64(piece.positions)
		local nrm = MeshData.base64(piece.normals)
		local uv = MeshData.base64(piece.uvs)
		local tri = MeshData.base64(piece.triangles)
		local colors = if piece.colors then MeshData.base64(piece.colors) else nil

		local vids = table.create(nPos)
		for i = 0, nPos - 1 do
			local x = buffer.readi16(pos, i * 6) / 32767 * hx
			local y = buffer.readi16(pos, i * 6 + 2) / 32767 * hy
			local z = buffer.readi16(pos, i * 6 + 4) / 32767 * hz
			vids[i + 1] = em:AddVertex(Vector3.new(x, y, z))
		end
		local nids = table.create(nNrm)
		for i = 0, nNrm - 1 do
			local n = Vector3.new(buffer.readi8(nrm, i * 3), buffer.readi8(nrm, i * 3 + 1), buffer.readi8(nrm, i * 3 + 2))
			nids[i + 1] = em:AddNormal(if n.Magnitude > 0 then n.Unit else Vector3.yAxis)
		end
		local cids: { number }? = nil
		if colors then
			local c = table.create(nPos)
			for i = 0, nPos - 1 do
				local col = Color3.fromRGB(buffer.readu8(colors, i * 3), buffer.readu8(colors, i * 3 + 1), buffer.readu8(colors, i * 3 + 2))
				c[i + 1] = em:AddColor(col, 1)
			end
			cids = c
		end
		local uids = table.create(nUv)
		for i = 0, nUv - 1 do
			uids[i + 1] = em:AddUV(Vector2.new(buffer.readu16(uv, i * 4) / 65535, buffer.readu16(uv, i * 4 + 2) / 65535))
		end
		for t = 0, piece.triangleCount - 1 do
			local base = t * 18
			local function corner(c: number): (number, number, number)
				local o = base + c * 6
				return buffer.readu16(tri, o), buffer.readu16(tri, o + 2), buffer.readu16(tri, o + 4)
			end
			local p0, n0, u0 = corner(0)
			local p1, n1, u1 = corner(1)
			local p2, n2, u2 = corner(2)
			local f = em:AddTriangle(vids[p0 + 1], vids[p1 + 1], vids[p2 + 1])
			em:SetFaceNormals(f, { nids[n0 + 1], nids[n1 + 1], nids[n2 + 1] })
			em:SetFaceUVs(f, { uids[u0 + 1], uids[u1 + 1], uids[u2 + 1] })
			if cids then
				em:SetFaceColors(f, { cids[p0 + 1], cids[p1 + 1], cids[p2 + 1] })
			end
		end
	end)
	if not ok then
		em:Destroy()
		error(err, 0)
	end
	return em
end

-- The message a full budget fails with: callers tell it apart from a broken
-- piece, because a slot can come free again (MeshData.release) and the piece
-- is worth asking for on the next car.
MeshData.BUDGET_ERROR = "editable mesh budget exhausted"

type Template = {
	part: MeshPart?,
	em: EditableMesh?,
	users: number,
	pending: boolean,
	done: BindableEvent,
	err: string?,
}
local templates: { [Piece]: Template } = {}

local function destroyTemplate(piece: Piece, t: Template)
	if templates[piece] == t then
		templates[piece] = nil
	end
	if t.part then
		t.part:Destroy()
	end
	if t.em then
		t.em:Destroy()
	end
end

-- One template MeshPart per piece, shared by every car showing it, made the
-- first time it is asked for. Clone it; do not parent it. Each acquire must
-- be matched by one release once nothing shows a clone any more: a template
-- holds one of the client's 8 EditableMesh slots (BEHAVIOURS.md), and a
-- MeshPart made from an EditableMesh goes blank when it is destroyed, so the
-- slot is only given back when the last user lets go (2026-11-07: with every
-- template kept for the session, the fifth new store car in a row came up
-- without its tail lamps and grille). Errors when it cannot be made; an
-- error containing BUDGET_ERROR means no slot was free.
--
-- Making one yields (CreateMeshPartAsync) and two cars can ask at once, so a
-- build is single-flight, as the garage's exhaust tips are (CarCosmetics):
-- later askers count themselves on the pending entry and wait for it.
function MeshData.acquire(piece: Piece): MeshPart
	local t = templates[piece]
	if t then
		t.users += 1
		if t.pending then
			t.done.Event:Wait()
		end
		if t.part then
			return t.part
		end
		t.users -= 1 -- the build this caller waited on failed
		error(t.err or "template failed", 0)
	end
	local entry: Template = { part = nil, em = nil, users = 1, pending = true, done = Instance.new("BindableEvent"), err = nil }
	templates[piece] = entry
	local ok, err = pcall(function()
		local em = MeshData.editable(piece)
		entry.em = em
		entry.part = AssetService:CreateMeshPartAsync(Content.fromObject(em), {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Precise,
		})
	end)
	entry.pending = false
	if not ok then
		entry.err = tostring(err)
		entry.part = nil
		destroyTemplate(piece, entry) -- a failed build must not keep its slot
		entry.done:Fire()
		error(entry.err, 0)
	end
	entry.done:Fire()
	if entry.users <= 0 then
		-- Everyone who asked let go while it was being made.
		destroyTemplate(piece, entry)
		error("released while it was being made", 0)
	end
	return entry.part :: MeshPart
end

-- Lets go of one acquire. The last one frees the template and its slot.
function MeshData.release(piece: Piece)
	local t = templates[piece]
	if not t then
		return
	end
	t.users -= 1
	if t.users <= 0 and not t.pending then
		destroyTemplate(piece, t)
	end
end

-- How many templates are alive: one EditableMesh slot each.
function MeshData.liveTemplates(): number
	local n = 0
	for _ in templates do
		n += 1
	end
	return n
end

return MeshData
