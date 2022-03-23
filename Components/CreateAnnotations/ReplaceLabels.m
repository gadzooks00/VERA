classdef ReplaceLabels < AComponent
    %CREATELABELS Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        ElectrodeLocationIdentifier
        ReplaceableLabels
        ReplacementRadius

    end
    
    methods
        function obj = ReplaceLabels()
            obj.ElectrodeLocationIdentifier='ElectrodeLocation';
            obj.ReplaceableLabels={'Right-Cerebral-White-Matter','Left-Cerebral-White-Matter','unknown','Unknown','Right-Hippocampus','Left-Hippocampus','Right-Amygdala','Left-Amygdala','Left-Cerebral-Cortex','Right-Cerebral-Cortex'};
            obj.ReplacementRadius=[3,3,10,10,1,1,1,1,10,10];
        end
        
        function Publish(obj)
            obj.AddInput(obj.ElectrodeLocationIdentifier,'ElectrodeLocation');
            obj.AddOutput(obj.ElectrodeLocationIdentifier,'ElectrodeLocation');
        end
        function Initialize(obj)
            if(length(obj.ReplaceableLabels) ~= length(obj.ReplacementRadius))
                error('Entries for ReplaceableRadius and Replacement Radius must be the same length!');
            end
        end

        function out=Process(obj,elLocs)
            out=obj.CreateOutput(obj.ElectrodeLocationIdentifier,elLocs);
            locsStruct.Label=elLocs.Label;%create struct to avoid handle issues
            locsStruct.Annotation=elLocs.Annotation;
            out.Label=cleanupLabels(locsStruct,obj.ReplaceableLabels,obj.ReplacementRadius).Label;
        end
    end
end
