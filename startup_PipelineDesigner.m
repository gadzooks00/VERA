% Startup VERA Pipeline Designer through this script

%Clear matlab environment
close all;
clearvars;
clc;

%add all paths
addpath(genpath('classes'));
addpath(genpath('Components'));
addpath(genpath('Dependencies'));
addpath(genpath('PipelineDesigner'));

%java stuff to make sure that the GUI works as expected
warning off
javaaddpath('Dependencies/Widgets Toolbox/resource/MathWorksConsultingWidgets.jar');
import uiextras.jTree.*;
warning on


%startup GUI
guihandle=PipelineDesigner();
addToolbarExplorationButtons(guihandle);