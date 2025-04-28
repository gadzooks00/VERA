classdef MoveRASOrigin4HHFU < AComponent
    %MoveRASOrigin4HHFU Moves the origin of RAS in a way that was working
    %for HHFU subjects
   properties
        Identifier
    end
    
    methods
        function obj = MoveRASOrigin4HHFU()
            obj.Identifier='CT';
        end
        function Publish(obj)
            obj.AddInput(obj.Identifier,'Volume');
            obj.AddOutput(obj.Identifier,'Volume');
        end
        function Initialize(~)
            
        end
        
        function [vol] = Process(~,vol)
            img_size=round(size(vol.Image.img)/2);
            if(vol.Image.hdr.dime.pixdim(1) == 1)
                vol.Image.hdr.hist.srow_x(4)=-vol.Image.hdr.dime.pixdim(2)*img_size(1);
                vol.Image.hdr.hist.srow_y(4)=-vol.Image.hdr.dime.pixdim(3)*img_size(2);
                vol.Image.hdr.hist.srow_z(4)=-vol.Image.hdr.dime.pixdim(4)*img_size(3);
            elseif(vol.Image.hdr.dime.pixdim(1) == -1) % James added this when testing HHFU001 (delete this elseif if anything breaks)
                vol.Image.hdr.hist.srow_x(4)=vol.Image.hdr.dime.pixdim(2)*img_size(1);
                vol.Image.hdr.hist.srow_y(4)=-vol.Image.hdr.dime.pixdim(3)*img_size(2);
                vol.Image.hdr.hist.srow_z(4)=-vol.Image.hdr.dime.pixdim(4)*img_size(3);
            else % the original else
                vol.Image.hdr.hist.srow_x(4)=-vol.Image.hdr.dime.pixdim(2)*img_size(1);
                vol.Image.hdr.hist.srow_y(4)=vol.Image.hdr.dime.pixdim(3)*img_size(2);
                vol.Image.hdr.hist.srow_z(4)=-vol.Image.hdr.dime.pixdim(4)*img_size(3);

            end
        end
    end
end

