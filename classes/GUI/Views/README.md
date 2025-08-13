Upgraded 3D model viewer for VERA.

"Install" by copying file to VERA/classes/GUI/Views.

May need to make an entry in pipeline.pwf:
```
<View Type="SuperModel3DView">
    <Name>"Super Cortex 3D View"</Name>
</View>
```

08-13: added ability to select channels to display by modifying
electodes.txt