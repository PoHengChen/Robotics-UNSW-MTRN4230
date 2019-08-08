
function z5014392_MTRN4230_ASST1(image_file_path, image_file_name,output_file_path, program_folder)
    
    clear all; clear figure; close all;
    
    image_file_path  = 'C:\Users\z5014\OneDrive - UNSW\MECHATRONIC ENG\18s2_mtrn4230\1. Computer Vision\auto_mark_2018_v1\auto_mark_2018_v1\training_set\IMG_038.jpg';
%     image_file_path  =  'D:\MTRN4230\1. Computer Vision\auto_mark_2018_v1\auto_mark_2018_v1\training_set\IMG_044.jpg';% Issue:42,34,33
    image_file_name  =  'IMG_001.jpg';
%     output_file_path =  'D:\MTRN4230\1. Computer Vision\auto_mark_2018_v1\auto_mark_2018_v1\student_results\z5014392_MTRN4230_ASST1_marks\IMG_045.txt';
    output_file_path =  'C:\Users\z5014\OneDrive - UNSW\MECHATRONIC ENG\18s2_mtrn4230\1. Computer Vision\auto_mark_2018_v1\auto_mark_2018_v1\student_results\z5014392_MTRN4230_ASST1_marks\IMG_045.txt';
%     program_folder   =  'D:\MTRN4230\1. Computer Vision\auto_mark_2018_v1\auto_mark_2018_v1\student_submissions';
    program_folder   =  'C:\Users\z5014\OneDrive - UNSW\MECHATRONIC ENG\18s2_mtrn4230\1. Computer Vision\auto_mark_2018_v1\auto_mark_2018_v1\student_submissions';

    im = imread(image_file_path);
    blocks = detect_blocks(im);
    write_output_file(blocks, image_file_name, output_file_path);
end

function info = detect_blocks(imageInput)
    load COLOR.mat;
    load SHAPE.mat;
    show1 = 1;  % figure1
    show2 = 1;  % figure2: blocks image
%% 1. Image pre-process (obtain mask)
    im = im2double(imageInput); % Intensity (0 ~ 1)
    im(1:230,:,:) = 1; % Filter afrea outside table
    if show1,figure(1);subplot(2,2,1);imshow(im);title('Raw Image');hold on;zoom on;end
    % (YCbCr): yellow is problematic, use YCbCr
    [mask123] = ycbcr_adjustment(im) ;
    mask123 = imdilate(mask123,strel('disk',4)); 
    % Extract blocks area
    gray = rgb2gray(im);
    mask_block = (gray < 0.55) | (mask123); 
    % Clean background line
    mask_block = imerode(mask_block, strel('disk',1));% cut line
    % letter mask
    mask_letter = ~mask_block;
    mask_letter = bwareafilt(mask_letter, [0 1000]);                        %figure;imshow(mask_letter);
    mask_letter_less_noise = imerode(mask_letter,strel('disk',2));
    mask_letter_less_noise = bwareafilt(mask_letter_less_noise, [100 1000]);           %figure;imshow(mask_letter_less_noise);
    mask_letter_less_noise_3d = repmat (mask_letter_less_noise, [1,1,3]);  %   figure;imshow(im);
    im(mask_letter_less_noise_3d) = 1;    %figure;imshow(im);

%     im = im .* mask_letter_less_noise;   figure;imshow(im);
    %==== ISSUE: tiny gap with size smaller than maximum letter size % ====
    mask_block = mask_block | mask123; % prevent red/orng/yel erode
    mask_block = bwareaopen(mask_block, 200); % clean rest of line pieces
    % Fill letter area (issue: space between blocks are filled too!!)% mask_block = imfill(mask_block,'holes');imshow(mask_block); % SOLVED! Instead of imfill, use 'letter_mask' to do 'OR operation'
    mask_block = mask_block | mask_letter; 
    % manage holes in letter
    mask_block = ~mask_block;
    mask_block = bwareaopen(mask_block, 250); % clean rest of line pieces
    mask_block = ~mask_block; 
    % Clean line connect with blocks
    mask_block = imerode(mask_block, strel('disk',1)); 
    % last clean
    mask_block = mask_block | mask123; % prevent red/orng/yel erode
    mask_block = bwareaopen(mask_block, 100); % clean rest of line pieces
    mask_block = imdilate(mask_block,strel('disk',2));

%% 2. Split connected blocks (obtain [x,y,theta])
    block_length = 50;
    tolerance = 500;
    blocks = {};
    info = [];
    
    % cut blocks to get [x, y, theta]
    block_regions = regionprops(mask_block, 'Centroid', 'Area', 'PixelIdxList');
    while 1
        for m = 1:size(block_regions,1)
            if block_regions(m).Area < block_length^2 - tolerance % ignore residual area
                mask_block(block_regions(m).PixelIdxList) = 0;
                continue; 
            end
            [blocks,mask_block] = blocksCut(blocks, block_regions(m), block_length,mask_block,im,show1);
        end
        block_regions = regionprops(mask_block, 'Centroid', 'Area', 'PixelIdxList');
        if size(block_regions,1)==0, break; end
    end

%% 3. classify blocks information (obtain [color, shape, letter, reachability])
    if show2,figure(2);end
    for i = 1:size(blocks,2) 
        if show2, subplot(8,5,i);imshow(blocks{4,i}); end
        
        color = double(classify(COLOR, 255*blocks{4,i}));
        if color == 7       % LETTER
            blocks{5,i} = 0;
            blocks{6,i} = 0;  
            % classify letter using Optimal character recognition method
            [blocks{7,i},blocks{3,i}] = character_ocr(blocks{4,i},blocks{3,i}); 
        else                % SHAPE
            blocks{5,i} = color;
            blocks{6,i} = double(classify(SHAPE, 255*blocks{4,i}));
            blocks{7,i} = 0;
        end

        % Reachability
        dist = sqrt((blocks{2,i}-806.34)^2 + (blocks{1,i}-26.124)^2);
        radius = 831.97;
        blocks{8,i} = dist < radius;
        info = vertcat(info,[blocks{2,i},blocks{1,i},deg2rad(blocks{3,i}),blocks{5,i},blocks{6,i},blocks{7,i},blocks{8,i}]);
    end
%     info
end

function write_output_file(blocks, image_file_name, output_file_path)
    
    fid = fopen(output_file_path, 'w');
    
    fprintf(fid, 'image_file_name:\n');
    fprintf(fid, '%s\n', image_file_name);
    fprintf(fid, 'rectangles:\n');
    fprintf(fid, ...
        [repmat('%f ', 1, size(blocks, 2)), '\n'], blocks');
    
    % Please ensure that you close any files that you open. If you fail to do
    % so, there may be a noticeable decrease in the speed of your processing.
    fclose(fid);
end