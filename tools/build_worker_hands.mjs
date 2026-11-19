import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

// Input files are the CC0 base mesh, skeleton and weights from MakeHuman.
// Keep the source files outside the game package.
const [source, destination] = process.argv.slice(2);
if (!source || !destination) throw new Error("Usage: node tools/build_worker_hands.mjs SOURCE DEST.json");
const skeleton = JSON.parse(readFileSync(join(source, "default.mhskel"), "utf8"));
const weights = JSON.parse(readFileSync(join(source, "default_weights.mhw"), "utf8")).weights;
const vertices = [], texcoords = [], body = [];
let group;
for (const line of readFileSync(join(source, "base.obj"), "utf8").split(/\r?\n/)) {
  const [kind, ...values] = line.trim().split(/\s+/);
  if (kind === "v") vertices.push(values.map(Number));
  if (kind === "vt") texcoords.push([+values[0], 1 - +values[1]]);
  if (kind === "g") group = values[0];
  if (kind === "f" && group === "body") {
    body.push(values.map(part => part.split("/").slice(0, 2).map(index => +index - 1)));
  }
}

const add = (a,b) => a.map((n,i) => n+b[i]);
const sub = (a,b) => a.map((n,i) => n-b[i]);
const mul = (a,n) => a.map(x => x*n);
const dot = (a,b) => a.reduce((sum,n,i) => sum+n*b[i],0);
const norm = a => mul(a, 1/Math.max(1e-8, Math.hypot(...a)));
const cross = ([x,y,z],[a,b,c]) => [y*c-z*b,z*a-x*c,x*b-y*a];
const mean = list => mul(list.reduce(add),1/list.length);
const lerp = (a,b,t) => add(mul(a,1-t),mul(b,t));
const round = n => Math.round(n*1e6)/1e6;
const clamp = (n,a,b) => Math.min(b,Math.max(a,n));
const joint = name => mean(skeleton.joints[name].map(index=>vertices[index]));
const head = name => joint(skeleton.bones[name].head);
const tail = name => joint(skeleton.bones[name].tail);

function makeHand(side) {
  const digitNames = [2,3,4,5,1].map(digit => [1,2,3].map(joint => `finger${digit}-${joint}.${side}`));
  const wrist = head(`wrist.${side}`);
  const knuckles = digitNames.slice(0, 4).map(digit => head(digit[0]));
  const mid = mean(knuckles);
  const up = norm(sub(mid,wrist));
  const fromIndex = mul(sub(knuckles[3],knuckles[0]),side === "R" ? 1 : -1);
  const right = norm(sub(fromIndex,mul(up,dot(fromIndex,up))));
  const back = cross(right,up);
  const local = p => {
    const q = sub(p,mid);
    return [dot(q,right)*.10,dot(q,up)*.10+.041,dot(q,back)*.10];
  };
  const wristLocal = local(wrist);
  const armBase = local(head(`lowerarm02.${side}`));
  const cuffY = wristLocal[1]-.125;
  const cuff = lerp(wristLocal,armBase,(cuffY-wristLocal[1])/(armBase[1]-wristLocal[1]));
  const armPins = [0,.33,.66].map(t => lerp(cuff,wristLocal,t));
  const joints = digitNames.map(digit => [...digit.map(name=>local(head(name))),local(tail(digit[2]))]);
  const segmentIds = new Map(digitNames.flat().map((name,i)=>[name,i+1]));
  const sideSign = side === "R" ? -1 : 1;
  const selection = body.filter(face =>
    face.every(([id])=>vertices[id][0]*sideSign>2.8) &&
    face.some(([id])=>local(vertices[id])[1]>=cuffY)
  );
  const picked = new Set(selection.flatMap(face=>face.map(([id])=>id)));
  const anatomyWeights = new Map([...picked].map(id=>[id,new Array(19).fill(0)]));
  for (const [name,influences] of Object.entries(weights)) {
    const bone = segmentIds.get(name) ?? 0;
    for (const [vertex,value] of influences) {
      if (anatomyWeights.has(vertex)) anatomyWeights.get(vertex)[bone] += value;
    }
  }
  const ids = new Map();
  const nodes = [...picked].map((id,index)=>{
    ids.set(id,index);
    const position = local(vertices[id]);
    const authored = anatomyWeights.get(id);
    const total = authored.reduce((a,b)=>a+b,0);
    const weight = total>0 ? mul(authored,1/total) : [1,...new Array(18).fill(0)];
    if (position[1]<wristLocal[1]) {
      weight.fill(0);
      const coordinate = clamp((position[1]-cuffY)/.125,0,1)*3;
      const section = Math.min(2,Math.floor(coordinate));
      weight[16+section] = 1-(coordinate-section);
      weight[section===2 ? 0 : 17+section] = coordinate-section;
    }
    return { position, weight };
  });
  let faces = selection.map(face=>face.map(([id,uv])=>({ id:ids.get(id),uv:texcoords[uv] })));
  const smooth = subdivide(nodes,faces);
  faces = smooth.faces;
  const symmetric = smooth.nodes;
  const normals = symmetric.map(()=>[0,0,0]);
  for (const face of faces) {
    const [a,b,c] = face.map(corner=>symmetric[corner.id].position);
    const n = cross(sub(b,a),sub(c,a));
    for (const {id} of face) normals[id] = add(normals[id],n);
  }
  const result = { positions:[], normals:[], uvs:[], bones:[], weights:[], indices:[], joints, armPins, wrist:wristLocal };
  const corners = new Map();
  for (const face of faces) {
    const ids = face.map(({id,uv})=>{
      const key = `${id}/${uv.map(round).join("/")}`;
      if (corners.has(key)) return corners.get(key);
      const index = result.positions.length/3;
      const node = symmetric[id];
      result.positions.push(...node.position.map(round));
      result.normals.push(...norm(normals[id]).map(round));
      result.uvs.push(...uv.map(round));
      const chosen = node.weight.map((w,b)=>[w,b]).sort((a,b)=>b[0]-a[0]).slice(0,4);
      const strength = chosen.reduce((v,[w])=>v+w,0);
      result.bones.push(...chosen.map(([,i])=>i));
      result.weights.push(...chosen.map(([w])=>round(w/strength)));
      corners.set(key,index);
      return index;
    });
    for(let i=2;i<ids.length;i++) result.indices.push(ids[0],ids[i],ids[i-1]);
  }
  result.joints = result.joints.map(digit=>digit.map(joint=>joint.map(round)));
  result.armPins = result.armPins.map(pin=>pin.map(round));
  result.wrist = result.wrist.map(round);
  return result;
}

function subdivide(nodes,faces) {
  const midpoint = list => ({
    position:mean(list.map(node=>node.position)), weight:mean(list.map(node=>node.weight)),
  });
  const faceCenters = faces.map(face=>midpoint(face.map(({id})=>nodes[id])));
  const adjacent = nodes.map(()=>({edges:new Set(),faces:[]}));
  const edges = new Map();
  const edgeKey = (a,b)=>a<b ? `${a}-${b}` : `${b}-${a}`;
  faces.forEach((face,i)=>{
    const ids = face.map(corner=>corner.id);
    ids.forEach((a,j)=>{
      const b = ids[(j+1)%ids.length];
      const key = edgeKey(a,b);
      if (!edges.has(key)) edges.set(key,{a,b,faceIds:[],midpoint:midpoint([nodes[a],nodes[b]])});
      edges.get(key).faceIds.push(i);
      adjacent[a].faces.push(i);
      adjacent[a].edges.add(key);
      adjacent[b].edges.add(key);
    });
  });
  const next = nodes.map((node,i)=>{
    const linked = [...adjacent[i].edges].map(key=>edges.get(key));
    const boundary = linked.filter(edge=>edge.faceIds.length===1);
    // Keep the cut under the sleeve smooth while retaining the real wrist loops.
    if (boundary.length) {
      const neighbors = boundary.map(edge=>nodes[edge.a===i ? edge.b : edge.a]);
      return {position:lerp(node.position,mean(neighbors.map(n=>n.position)),.25),weight:node.weight};
    }
    const f = mean(adjacent[i].faces.map(id=>faceCenters[id].position));
    const r = mean(linked.map(edge=>edge.midpoint.position));
    const n = linked.length;
    return {position:mul(add(add(f,mul(r,2)),mul(node.position,n-3)),1/n),weight:node.weight};
  });
  for(const edge of edges.values()) {
    edge.index = next.length;
    const samples = [nodes[edge.a],nodes[edge.b]];
    if (edge.faceIds.length===2) samples.push(...edge.faceIds.map(id=>faceCenters[id]));
    next.push(midpoint(samples));
  }
  const sections = faces.flatMap((face,i)=>{
    const center = {id:next.length,uv:mean(face.map(corner=>corner.uv))};
    next.push(faceCenters[i]);
    return face.map((corner,j)=>{
      const previous = face[(j+face.length-1)%face.length];
      const following = face[(j+1)%face.length];
      const edge = (a,b)=>({id:edges.get(edgeKey(a.id,b.id)).index,uv:mean([a.uv,b.uv])});
      return [corner,edge(corner,following),center,edge(previous,corner)];
    });
  });
  return {nodes:next,faces:sections};
}

const hands = [makeHand("L"),makeHand("R")];
const uvs = hands.flatMap(hand=>hand.uvs);
const range = axis => {
  const values = uvs.filter((_,i)=>i%2===axis);
  return [Math.min(...values),Math.max(...values)];
};
const [u0,u1] = range(0);
const [v0,v1] = range(1);
const crop = [clamp(u0-.006,0,1),clamp(v0-.006,0,1),clamp(u1+.006,0,1),clamp(v1+.006,0,1)].map(round);
for(const hand of hands) {
  for(let i=0;i<hand.uvs.length;i++) {
    const axis = i%2;
    hand.uvs[i] = round((hand.uvs[i]-crop[axis])/(crop[2+axis]-crop[axis]));
  }
}
writeFileSync(destination,JSON.stringify({crop,hands}));
console.log(hands.map(hand=>`${hand.positions.length/3} vertices, ${hand.indices.length/3} triangles`).join(" / "));
console.log("Texture crop",crop);
console.log("Right joints",hands[1].joints,"Wrist",hands[1].wrist,"Forearm",hands[1].armPins);
