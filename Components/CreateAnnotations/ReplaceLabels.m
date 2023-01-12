classdef ReplaceLabels < AComponent
    %CREATELABELS The ReplaceLabels Component tries 
    % to simplify existing electrode location labels based on some simple rules. 
    % Rules will be applied iterative.
    
    properties
        ElectrodeLocationIdentifier
        ReplaceableLabels
        ReplacementRadius

    end
    
    methods
        function obj = ReplaceLabels()
            obj.ElectrodeLocationIdentifier='ElectrodeLocation';
            obj.ReplaceableLabels={'Right-Cerebral-White-Matter','unknown','Left-Cerebral-White-Matter','Right-Hippocampus','Left-Hippocampus','Right-Amygdala','Left-Amygdala','Left-Cerebral-Cortex','Right-Cerebral-Cortex'};
            obj.ReplacementRadius=[3,0,3,1,1,1,1,10,10];
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
            cleanedLabels=cleanupLabels(locsStruct,obj.ReplaceableLabels,obj.ReplacementRadius);
            out.Label=cleanedLabels.Label;
        end
    end
end

