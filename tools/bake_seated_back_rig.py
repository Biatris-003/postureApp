import bpy
from mathutils import Vector

SOURCE=r"C:\Users\Ayat\Downloads\Seated Idle.fbx"
CHAIR=r"C:\Users\Ayat\Downloads\Office Chair.glb"
OUT=r"D:\GP\the mobile app\postureApp\assets\models\seated_patient.glb"
PREVIEW=r"D:\GP\the mobile app\postureApp\assets\models\baked_back_rig_preview.png"
def bounds(meshes):
 p=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box];return Vector((min(v.x for v in p),min(v.y for v in p),min(v.z for v in p))),Vector((max(v.x for v in p),max(v.y for v in p),max(v.z for v in p)))
def look(o,t):o.rotation_euler=(Vector(t)-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.fbx(filepath=SOURCE,global_scale=.35);rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');body=next(o for o in bpy.context.scene.objects if o.type=='MESH');body.name='SeatedCharacterBody';bpy.context.scene.frame_set(1)
# Convert the chosen seated Mixamo frame into the skeleton's neutral pose.
bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='POSE');bpy.ops.pose.armature_apply(selected=False);bpy.ops.object.mode_set(mode='OBJECT');rig.animation_data_clear();bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT');bpy.ops.import_scene.gltf(filepath=CHAIR);chairs=[o for o in bpy.context.selected_objects if o.type=='MESH'];lo,hi=bounds(chairs);center=(lo+hi)*.5
for o in chairs:o.scale*=.05;o.location=(o.location-center)*.05;o.name='OfficeChair'
# Preview baked result.
bpy.ops.object.light_add(type='AREA',location=(3.5,-4.5,5.5));key=bpy.context.object;key.data.energy=850;key.data.size=4;look(key,(0,0,1));bpy.ops.object.light_add(type='AREA',location=(-3,-1,2.5));fill=bpy.context.object;fill.data.energy=400;fill.data.size=3;look(fill,(0,0,1));bpy.ops.object.camera_add(location=(4.2,-6.2,2.8));cam=bpy.context.object;look(cam,(0,0,1.05));s=bpy.context.scene;s.camera=cam;s.render.engine='BLENDER_EEVEE';s.render.resolution_x=700;s.render.resolution_y=700;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.render.filepath=PREVIEW;s.world=bpy.data.worlds.new('World');s.world.color=(.035,.05,.08);bpy.ops.render.render(write_still=True)
bpy.data.objects.remove(cam,do_unlink=True);bpy.data.objects.remove(key,do_unlink=True);bpy.data.objects.remove(fill,do_unlink=True)
bpy.ops.object.select_all(action='DESELECT')
for o in [rig,body]+chairs:o.select_set(True)
bpy.context.view_layer.objects.active=rig;bpy.ops.export_scene.gltf(filepath=OUT,export_format='GLB',use_selection=True,export_animations=False)
