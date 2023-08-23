% Startup VERA through this script


%Clear matlab environment
close all;
clearvars;
clc;
%restoredefaultpath;


%add all paths
addpath(genpath('classes'));
addpath(genpath('Components'));
addpath(genpath('Dependencies'));

%java stuff to make sure that the GUI works as expected
warning off
javaaddpath('Dependencies/Widgets Toolbox/resource/MathWorksConsultingWidgets.jar');
import uiextras.jTree.*;
warning on

if ~any(any(contains(struct2cell(ver), 'Image Processing Toolbox')))
    error('Please check if the Image Processing Toolbox is installed!');
end
if ~any(any(contains(struct2cell(ver), 'MATLAB Report Generator')))
    error('Please check if the MATLAB Report Generator is installed!');
end
if ~any(any(contains(struct2cell(ver), 'Statistics and Machine Learning Toolbox')))
    error('Please check if the Statistics and Machine Learning Toolbox is installed!');
end
if ~any(any(contains(struct2cell(ver), 'Computer Vision Toolbox')))
    error('Please check if the Computer Vision Toolbox is installed!');
end

%startup GUI
guihandle=MainGUI();
addToolbarExplorationButtons(guihandle);