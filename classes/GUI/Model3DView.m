classdef Model3DView < AView & uix.Grid
    %Model3DView - View of a Surface
    %   Shows a Surface and the Electrode Locations if available
    properties
        SurfaceIdentifier %Identifier for which surface to show
        ElectrodeLocationIdentifier %Identifier for the Electrode Location to be shown
        ElectrodeDefinitionIdentifier
    end
    properties (Access = private)
        axModel
        requiresUpdate = false
        cSlider
        vSurf
    end
    
    methods
        function obj = Model3DView(varargin)
            %MODEL3DVIEW Construct an instance of this class
            obj.SurfaceIdentifier='Surface';
            obj.ElectrodeLocationIdentifier='ElectrodeLocation';
            obj.ElectrodeDefinitionIdentifier='ElectrodeDefinition';
            opengl hardware;
            tmp_Grid=uix.Grid('Parent',obj);
            obj.axModel=axes('Parent',uicontainer('Parent',tmp_Grid),'Units','normalized','Color','k','ActivePositionProperty', 'Position');
            set(tmp_Grid,'BackgroundColor','k');
            set(obj,'BackgroundColor','k');
            obj.cSlider=uicontrol('Parent',obj,'Style','slider','Min',0,'Max',1,'Value',1);
            addlistener(obj.cSlider, 'Value', 'PreSet',@obj.changeAlpha);
            obj.Widths=[-1];
            obj.Heights=[-1, 15];
             try
                uix.set( obj, varargin{:} )
             catch e
                delete( obj )
                e.throwAsCaller()
            end
        end
        

    end
    
    methods(Access = protected)
        function changeAlpha(obj,~,~)
            if(~isempty(obj.vSurf))
                alpha(obj.vSurf,obj.cSlider.Value);
            end
        end
        
        function dataUpdate(obj)
            obj.updateView();
        end
        
        function updateView(obj)
            if(~obj.AvailableData.isKey(obj.SurfaceIdentifier))
                cla(obj.axModel);
                obj.vSurf=[];
                return;
            end
            surface=obj.AvailableData(obj.SurfaceIdentifier);
            hold(obj.axModel,'off');
            
              if(~isempty(surface))
                    if(~isempty(surface.Model) && isempty(surface.Annotation))
                        obj.vSurf=plot3DModel(obj.axModel,surface.Model);
                       % trisurf(surface.Model.tri, surface.Model.vert(:, 1), surface.Model.vert(:, 2), surface.Model.vert(:, 3) ,'Parent',obj.axModel,settings{:});
                    elseif(~isempty(surface.Model) && ~isempty(surface.Annotation))
                        [annotation_remap,cmap,names,name_id]=createColormapFromAnnotations(surface);
                        obj.vSurf=plot3DModel(obj.axModel,surface.Model,annotation_remap);
                       % trisurf(surface.Model.tri, surface.Model.vert(:, 1), surface.Model.vert(:, 2), surface.Model.vert(:, 3),annotation_remap ,'Parent',obj.axModel,settings{:});
                        colormap(obj.axModel,cmap);
                        
                        %light(obj.axModel,'Position',[-1 0 0]);
                       % camlight(obj.axModel,'headlight');
                        material(obj.axModel,'dull');
                        elIdentifiers=obj.ElectrodeLocationIdentifier;
                        elDefIdentifiers=obj.ElectrodeDefinitionIdentifier;
                        if(~iscell(obj.ElectrodeLocationIdentifier))
                            elIdentifiers={obj.ElectrodeLocationIdentifier};
                        end
                        if(~iscell(obj.ElectrodeDefinitionIdentifier))
                            elDefIdentifiers={obj.ElectrodeDefinitionIdentifier};
                        end
                        for i_elId=1:length(elIdentifiers)
                            
                            if(obj.AvailableData.isKey(elIdentifiers{i_elId}))
                                elPos=obj.AvailableData(elIdentifiers{i_elId});
                                if(~isempty(elPos) && ~isempty(elPos.DefinitionIdentifier))
                                    for i=unique(elPos.DefinitionIdentifier)'
                                        plotBallsOnVolume(obj.axModel,elPos.Location(elPos.DefinitionIdentifier==i,:),[],2);
                                        if(obj.AvailableData.isKey(elDefIdentifiers{i_elId}))
                                            elDef=obj.AvailableData(elDefIdentifiers{i_elId});
                                            names{end+1}=elDef.Definition(i).Name;
                                            name_id(end+1)=length(name_id)+1;
                                        end
                                    end

                                end
                            
								for i=1:size(elPos.Location,1)
									text(obj.axModel,elPos.Location(i,1)+1,elPos.Location(i,2)+1,elPos.Location(i,3)+1,num2str(i),'FontSize',14,'Color','w');
								end
							end
                        end
                       
                        cb=colorbar(obj.axModel,'Ticks',name_id+0.5,'TickLabels',names,'FontSize',12,'location','east');
                        set(cb,'TickLabelInterpreter','none')
                    end
                    alpha(obj.vSurf,obj.cSlider.Value);
                    
                    set(obj.axModel,'AmbientLightColor',[1 1 1])
                    %zoom(obj.axModel,'on');
                   
                     set(obj.axModel,'xtick',[]);
                      set(obj.axModel,'ytick',[]);
                     axis(obj.axModel,'equal');
                     axis(obj.axModel,'off');
                     xlim(obj.axModel,'auto');
                     ylim(obj.axModel,'auto');
                     set(obj.axModel,'Color','k');
                     set(obj.axModel,'clipping','off');
                     set(obj.axModel,'XColor', 'none','YColor','none','ZColor','none')                    
             else
                 delete(obj.axModel.Children);
             end
        end
    end

end

