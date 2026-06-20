import bpy
from mathutils import Vector
SOURCE=r"C:\Users\Ayat\Downloads\Seated Idle.fbx"
CHAIR=r"C:\Users\Ayat\Downloads\Office Chair.glb"
OUT=r"D:\GP\the mobile app\postureApp\assets\models\seated_patient.glb"
def bounds(meshes):
 p=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box];return Vector((min(v.x for v in p),min(v.y for v in p),min(v.z for v in p))),Vector((max(v.x for v in p),max(v.y for v in p),max(v.z for v in p)))
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.fbx(filepath=SOURCE,global_scale=.35);rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');body=next(o for o in bpy.context.scene.objects if o.type=='MESH');body.name='SeatedCharacterBody';bpy.context.scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT');bpy.ops.import_scene.gltf(filepath=CHAIR);chairs=[o for o in bpy.context.selected_objects if o.type=='MESH'];lo,hi=bounds(chairs);center=(lo+hi)*.5
for o in chairs:o.scale*=.05;o.location=(o.location-center)*.05;o.name='OfficeChair'
bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get();ev=body.evaluated_get(deps);mesh=ev.to_mesh();minz=min((ev.matrix_world@v.co).z for v in mesh.vertices);ev.to_mesh_clear();rig.location.z-=minz;bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
for o in [rig,body]+chairs:o.select_set(True)
bpy.context.view_layer.objects.active=rig;bpy.ops.export_scene.gltf(filepath=OUT,export_format='GLB',use_selection=True,export_animations=True,export_force_sampling=True)
