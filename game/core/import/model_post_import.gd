@tool
extends EditorScenePostImport
## Post-import hook for generated models. Set it as `import_script/path` in a `.glb.import`
## (tools/validate_data.py checks every model has it). The rules live in `ModelImportRules`.


func _post_import(scene: Node) -> Object:
	return ModelImportRules.process(scene, get_source_file())
