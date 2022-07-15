classdef Runner < handle
    %Runner The Runner handles execution of Components from a Project 
    %   The Runner determines if a Component can be executed or not and the
    %   current status of the component
    %   Status possiblities:
    %   Invalid: A Component has returned an error while execution of a stage and needs to be reconfigured
    %   Configured: Component has been configured correctly but is waiting for Data from another Component
    %   Ready: Component is Configured and Data is availbable; Component can be executed
    %   Completed: Component has been executed and produced correct output
    %   data
    properties (GetAccess = public)
        %ComponentStatus containers.Map % Invalid, Configured, Ready, Completed
        Components %Components of the Pipeline in the runner
        ComponentResultPath containers.Map %Resultpaths of all components
        Project Project %Project handled by the Runner
        CurrentPipelineData containers.Map % Available Data at the current completion Status of the Pipeline
    end
    
    
    methods(Static)
        function runner=CreateFromProject(prj)
            %CreateFromProject - Create a new Runner object for a Project
            %prj - Project object
            %returns Runner object
            %See also Project, Pipeline
            runner=Runner();
            runner.SetProject(prj);
        end
    end
    
    methods
        function obj = Runner()
            obj.Project;
            obj.CurrentPipelineData = containers.Map();
            obj.Components = {};
            obj.ComponentResultPath = containers.Map;
        end
        
        function status=GetComponentStatus(obj,name)
            %GetComponentStatus Returns the status of a Component
            % returns Component Status
            status=obj.Project.Pipeline.GetComponent(name).ComponentStatus;
        end
        
          function a = get.Components(obj)
              %get.Components get modifier for Components property
             a = obj.Project.Pipeline.Components;
          end
          
          function compId=GetNextReadyComponent(obj)
              %GetNextReadyComponent - Returns a list of components ready
              %to be executed
              %returns one Component ready to be executed
              compId={};
                for k=obj.Components
                    if(strcmp(obj.GetComponentStatus(k{1}),'Ready'))
                        compId=k{1};
                        return;
                    end
                        
                end
          end
        
        function SetProject(obj,project)
            %SetProject - Set the Project for the Runner
            if(isObjectTypeOf(project,'Project'))
                ppline=project.Pipeline;
                k=ppline.Components;
                compStatus=containers.Map();
                for i=1:length(k)
                    try
                        ppline.Components(k{i}).Initialize();
                        compStatus(k{i})='Configured';
                    catch e
                        compStatus(k{i})='Invalid';
                    end
                end
                obj.Project=project;
                obj.CurrentPipelineData = containers.Map();
                obj.updateCurrentResults();
            else
                error('Cannot set Project, value has to be object of type Project');
            end
        end
        
        function ReloadResults(obj,compName)
            obj.SetComponentStatus(compName,'Completed');
            obj.updateCurrentResults();
        end
        
        function ConfigureComponent(obj,compName)
            %ConfigureComponent - Run Configuration for a Component
            % If a completed component is reconfigured, it will remain
            % completed
            % compName - name of the Component to be configured
            wasrdy=false;
             if(strcmp(obj.GetComponentStatus(compName),'Completed'))
                 wasrdy=true;
             end
            try
                o=obj.Project.Pipeline.GetComponent(compName);
                o.Initialize();
                obj.SetComponentStatus(compName,'Configured');
                obj.updateComponentStatus();
                if(strcmp(obj.GetComponentStatus(compName),'Ready')) %check if results are available...
                    if(wasrdy && obj.Project.ComponentDataAvailable(compName))
                        obj.SetComponentStatus(compName,'Completed')
                    end
                end
                obj.updateComponentStatus();
            catch e
                warning on;
                warning(getReport( e, 'extended', 'hyperlinks', 'on' ));
                obj.updateComponentStatus();
                error(['Error during initialization of Component: ' e.message]);
            end
            
        end
        
        function ResetComponent(obj,compName)
            %Reset the Status of a component
            %Downgrades a completed component to a ready component and
            %update the Pipeline accordingly
            %See also Pipeline
            obj.resetDownstreamCompletionStatus(compName);
        end
        
        function inpComp=GetInputComponentNames(obj)
            %GetInputComponentNames - Returns all Input Components
            %An Input Component is defined as a Component which does not
            %require Inputs
            %See also Pipeline, AComponent
                inpComp=obj.Project.Pipeline.GetInputComponentNames();
        end

        function outComp=GetOutputComponentNames(obj)
            %GetOutputComponentNames - Returns all Output Components
            %An Output Component is defined as a Component which does not
            %produce Outputs
            %See also Pipeline, AComponent
                outComp=obj.Project.Pipeline.GetOutputComponentNames();
        end
        
        function outComp=GetProcessingComponentNames(obj)
            %GetProcessingComponentNames - Returns all Processing Components
            %A Processing Component is defined as a Component which does
            %require Inputs and produces Outputs
            %See also Pipeline, AComponent
                outComp=obj.Project.Pipeline.GetProcessingComponentNames();
        end
        
        function execSequence=GetProcessingSequence(obj,compName)
            execSequence=obj.Project.Pipeline.GetProcessingSequence(compName);
        end
        
        
        function RunComponent(obj,compName,silent)
            %RunComponent - Executes a component by calling its Process
            %function
            % Method will check if the Component can be run as well as load
            % and store all the necessary input and output data for the
            % Component
            % See also AComponent, AData, Pipeline
            if(~exist('silent','var'))
                silent=false;
            end
            compValid=true;
            if(~silent)
                h=waitbar(0,'Validating Pipeline...');
            end
            localPipeline=containers.Map();
            obj.checkCompName(compName);
             if(strcmp(obj.GetComponentStatus(compName),'Completed'))
                    obj.ConfigureComponent(compName);
                    obj.resetDownstreamCompletionStatus(compName);
                    obj.updateComponentStatus();
             end
            [~,req_comps]=inedges(obj.Project.Pipeline.DependencyGraph,compName);
            errStr=[];
            if(~silent)
                h=waitbar(0.3,'Gathering Input Data...');
            end
            for i=1:length(req_comps)
                if(~strcmp(obj.GetComponentStatus(req_comps{i}),'Completed'))
                    compValid=false;
                    errStr=[errStr ' ' req_comps{i}];
                else
                    localPipeline=[localPipeline; obj.Project.LoadComponentData(req_comps{i})];
                end
                h=waitbar(i/length(req_comps),h);
            end
            if(~compValid)
                error([compName 'requires the Output(s) from ' errStr ' first!']);
            end
            if(~strcmp(obj.GetComponentStatus(compName),'Ready') && ~strcmp(obj.GetComponentStatus(compName),'Completed'))
                error('Current component needs to be configured first!');
            end
                
            if(~silent) h=waitbar(0.7,'Gathering Input Data...'); end
            [inp, outp,optInp]=obj.Project.Pipeline.InterfaceInformation(compName);
            inpData=cell(numel(inp),1);
            outpData=cell(numel(outp),1);
            optinpData={};
            
            for i=1:length(inp)
                if(localPipeline.isKey(inp{i}))
                    inpData{i}=localPipeline(inp{i});
                else
                    warning('Requested Component Input is not available!');
                end
            end
            
            for i=1:length(optInp)
                optDataComp=obj.Project.Pipeline.FindUpstreamData(compName,optInp{i});
                if(strcmp(obj.GetComponentStatus(optDataComp),'Completed'))
                    data=obj.Project.LoadComponentData(optDataComp);
                    optinpData{end+1}=optInp{i};
                    optinpData{end+1}=data(optInp{i});
                end


            end
            
           if ~silent h=waitbar(1,'Running...');
           close(h);
           end
            try
                o=obj.Project.Pipeline.GetComponent(compName);
                
                [outpData{:}]=o.Process(inpData{:},optinpData{:});
                obj.SetComponentStatus(compName,'Completed');
                savepaths=obj.Project.SaveComponentData(compName,outpData{:});%the result paths are accumulative
                idx=find(strcmp(obj.Components,compName));
                if(idx > 1)
                    if(obj.ComponentResultPath.isKey(obj.Components{idx-1}))
                        res=obj.ComponentResultPath(obj.Components{idx-1}); %get previous results if it
                        for k=keys(savepaths)
                            res(k{1})=savepaths(k{1});
                        end
                        savepaths=res;
                    end
                end
                obj.ComponentResultPath(compName)=savepaths;
                for i=1:length(outp)
                    obj.CurrentPipelineData(outp{i})=outpData{i};
                end
            catch me
                %restore old input data
                
                warning on;
                warning(getReport( me, 'extended', 'hyperlinks', 'on' ));
                obj.SetComponentStatus(compName,'Invalid');
                
            end
            obj.updateComponentStatus();
            obj.updateCurrentResults();
            if(exist('me','var'))
                rethrow(me);
            end
        end
        
    end
    
    methods(Access = protected)
        function reset(obj)
            obj.CurrentPipelineData= containers.Map();
            obj.Project = [];
        end
        
        function SetComponentStatus(obj,name,status)
            %SetComponentStatus - Set the status of a component
            %name - name of the Component
            %status - new status of the component
            if(any(strcmp({'Invalid', 'Configured', 'Ready', 'Completed'},status)))
                obj.Project.Pipeline.GetComponent(name).ComponentStatus=status;
                obj.Project.SaveComponent(name);
            else
                error([status 'is not an allowed ComponentStatus']);
            end
        end
        
        function resetDownstreamCompletionStatus(obj,compName)
           %resetDownstreamCompletionStatus - Resets the Completion status
           %of a component and updates the pipeline
           
            if(strcmp(obj.GetComponentStatus(compName),'Completed'))
                obj.SetComponentStatus(compName,'Configured');
                [~,targComps]=outedges(obj.Project.Pipeline.DependencyGraph,compName);
                for i=1:length(targComps)
                    if (strcmp(obj.GetComponentStatus(targComps{i}),'Completed'))
                        obj.resetDownstreamCompletionStatus(targComps{i});
                    end
                end
            end
            obj.updateCurrentResults();
        end
        
        function updateCurrentResults(obj)
            %updateCurrentResults - Update all Data
             complRes=containers.Map();
             for c=obj.Components
                 if(strcmp(obj.GetComponentStatus(c{1}),'Completed'))
                     [~,outp]=obj.Project.Pipeline.InterfaceInformation(c{1});
                     for res=outp
                         complRes(res{1})=c{1};
                     end
                 end
             end
            %update SavePaths & objects
            warning on;
            obj.ComponentResultPath=containers.Map();
            obj.CurrentPipelineData=containers.Map();
            for k=keys(complRes)
                try
                    [res,path]=obj.Project.LoadComponentData(complRes(k{1}));
                    obj.ComponentResultPath(k{1})=path;
                    obj.CurrentPipelineData(k{1})=res(k{1});
                catch e
                    warning(['Could not load result from Component ' complRes(k{1}) ' Reason: ' getReport(e)]);
                    obj.resetDownstreamCompletionStatus(complRes(k{1}));
                end

                
            end
        end
        
        
        function updateComponentStatus(obj)
            %updateComponentStatus - Update all Component Status
            %Descriptors
            for k=obj.Components
                compRdy=true;
                req_comps=obj.Project.Pipeline.GetProcessingSequence(k{1});
                %[~,req_comps]=inedges(obj.Project.Pipeline.DependencyGraph,k{1});
                for i=1:length(req_comps)
                    if(~strcmp(obj.GetComponentStatus(req_comps{i}),'Completed'))
                        compRdy=false;
                    end
                end
                if(compRdy && strcmp(obj.GetComponentStatus(k{1}),'Configured'))
                    obj.SetComponentStatus(k{1},'Ready');
                end
            end
           
            
        end
        
        function checkCompName(obj,name)
            if(~any(strcmp(obj.Project.Pipeline.Components,name)))
                error([name 'is not a valid Component in this Pipeline']);
            end
        end
    end
end

