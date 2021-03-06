% function [a,Orig_image,Clean_image,present_J,present_t] = main(beta, gamma, delta)

%% For laproscopic image dehazing
close all;

%% My variable parameters
beta = 0.1;  % constant multiplier to priorpenelty(t(x)) in objective function
gamma = 1; % constant multiplier to priorpenelty(J(x)) in objective function
delta = 4; % weight for the Dark Channel Prior
zeta = 0.5; % weight for the specularity sparsity prior
xi = 2; % weight of the specularity image smoothness term

%% My parameters
n_var = 0.01;
tau = 0.05; % gradient descent step size
% beta = 6;  % constant multiplier to priorpenelty(t(x)) in objective function
% gamma = 0.3; % constant multiplier to priorpenelty(J(x)) in objective function
% delta = 1; % weight for the Dark Channel Prior
beta_of = 1;% huber function parameter for t(x)
gamma_of = 0.2; % huber function parameter for J(x)
% conv_par = 280; % Convergence parameter for gradient descent
max_iter = 50; % Maximum iterations

k_green = 2.3952;
k_blue = 2.7056;
k_red = 4.1693;
theta_green = 23.8942;
theta_blue = 20.20;
theta_red = 25.1374;
%% Estimate for A
% We need a handle on finding A for which we will use the method proposed

    Orig_image = imread('Spec_sim_3.png');
%     Orig_image = imresize(Orig_image,0.25);
    
    Orig_image = double(Orig_image) ./ 255;   
    Orig_image = Orig_image + n_var * randn(size(Orig_image));
    Clean_image = imread('Original.png');
    Clean_image = im2double(Clean_image);
%     comp_image = im2double(imread('data_img.png'));
    % We generate the dark channel prior at every pixel, using window size
    % and zero padding
    
    dark_ch = makeDarkChannel(Orig_image,3);
    
    %   Estimate Atmosphere
    
    %  We first pick the top 0.1% bright- est pixels in the dark channel.
    %  These pixels are most haze- opaque (bounded by yellow lines in 
    %  Figure 6(b)). Among these pixels, the pixels with highest intensity 
    %  in the input image I is selected as the atmospheric light.     
    %
%     % TL;DR  TAKE .1% of the brightest pixels
    dimJ = size(dark_ch);
%     numBrightestPixels = ceil(0.001 * dimJ(1) * dimJ(2)); % Use the cieling to overestimate number needed
%     A_est = estimateA(Orig_image,dark_ch,numBrightestPixels);
    A_est = imread('A_pGT.png');
  %   A_est = ACheck(Orig_image);
    A_est = im2double(A_est);  
    A = [A_est(1,1,1)  A_est(1,1,2)  A_est(1,1,3)];

present_J = zeros(size(Orig_image));
% present_Js = init_spec(Orig_image);
present_Js = im2double(imread('specular_orig.png'));
% present_Js = load('spec.mat');
% present_Js = present_Js.p;
% present_Js =ones(size(Orig_image,1),size(Orig_image,2));
k = size(present_J);
present_t = double(ones(k(1),k(2)));
present_A = A_est;
present_Js = repmat(present_Js, 1, 1, 3);
modelFidelityTerm = modelFidelity(Orig_image, present_J + present_Js, present_t, present_A);
obj_fn = sum(sum(sum(modelFidelityTerm.^2))) + ...
     beta * edgePrior(present_t, beta_of, 0) + ...   
     gamma * edgePrior(present_J(:, :, 1), gamma_of, 0) + ...
     gamma * edgePrior(present_J(:, :, 2), gamma_of, 0) + ...
     gamma * edgePrior(present_J(:, :, 3), gamma_of, 0) + ...
     delta * kl_div(present_J(:,:,1),k_red,theta_red) + ...
     delta * kl_div(present_J(:,:,2),k_green,theta_green) + ...
     delta * kl_div(present_J(:,:,3),k_blue,theta_blue) - ...
     zeta * sparsePrior(present_Js(:,:,1)) - ...
     zeta * sparsePrior(present_Js(:,:,2)) - ...
     zeta * sparsePrior(present_Js(:,:,3)) + ...
     xi * edgePrior(present_Js(:,:,1), 1, 0) + ...
     xi * edgePrior(present_Js(:,:,2), 1, 0) + ...
     xi * edgePrior(present_Js(:,:,3), 1, 0) ;
     
obj_fns = double(zeros(max_iter, 1));
J_update = double(zeros(size(present_J)));
previous_J = present_J;
previous_t = present_t;
iter = 1;
prev_obj_fn = obj_fn;

while iter <= max_iter %&& (prev_obj_fn >= obj_fn || iter < 3)
    
    obj_fns(iter) = obj_fn;
    prev_obj_fn = obj_fn;
    previous_J = present_J;
    previous_t = present_t;
    % Calculate the update
    t_update = 2 * sum(modelFidelityTerm, 3) .* ...
               (A(1) - present_J(:, :, 1) - present_Js(:,:,1) + ...
                A(2) - present_J(:, :, 2) - present_Js(:,:,2) + ...
                A(3) - present_J(:, :, 3)) - present_Js(:,:,3) + ...
                beta * priorUpdate(present_t, beta_of);
    
    for i = 1:3
        J_update(:, :, i) = -2 * modelFidelityTerm(:, :, i) .* present_t + ...
                            gamma * priorUpdate(present_J(:, :, i), gamma_of);
    end
%     J_update(:, :, 2) = J_update(:, :, 2) + delta * gamma_derivative(present_J(:, :, 2).*255, k_green, theta_green);
%     J_update(:, :, 3) = J_update(:, :, 3) + delta * gamma_derivative(present_J(:, :, 3).*255, k_blue, theta_blue);    
%     J_update(:, :, 1) = J_update(:, :, 1) + delta * gamma_derivative(present_J(:, :, 1).*255, k_red, theta_red);
    
    J_temp = imhistmatch(present_J, Clean_image, 255);
    J_update = J_update + delta*(J_temp - present_J);
    
    for i = 1:3
    Js_update(:,:,i) = -2 * modelFidelityTerm(:,:,i) .* present_t - ...
                zeta * sign(present_Js(:,:,i)) + xi * priorUpdate(present_Js(:,:,i), 1);
    end
    % Perform the update
    present_J = present_J + tau * J_update;
    
    present_J = check(present_J,0);
     present_J = check(present_J,1);
     present_J = imhistmatch(present_J,Clean_image);
    present_t = present_t + tau * t_update;
    present_t = check(present_t,0);
    present_Js = present_Js + tau * Js_update;
    present_Js = check(present_Js, 0);
    present_Js = check(present_Js, 1);
    
    modelFidelityTerm = modelFidelity(Orig_image, present_J + present_Js, present_t, present_A);
    obj_fn = sum(sum(sum(modelFidelityTerm.^2))) + ...
         beta * edgePrior(present_t, beta_of, 0) + ...   
         gamma * edgePrior(present_J(:, :, 1), gamma_of, 0) + ...
         gamma * edgePrior(present_J(:, :, 2), gamma_of, 0) + ...
         gamma * edgePrior(present_J(:, :, 3), gamma_of, 0) + ...
         delta * kl_div(present_J(:,:,1),k_red,theta_red) + ...
         delta * kl_div(present_J(:,:,2),k_green,theta_green) + ...
         delta * kl_div(present_J(:,:,3),k_blue,theta_blue) - ...
         zeta * sparsePrior(present_Js(:,:,1)) - ...
     zeta * sparsePrior(present_Js(:,:,2)) - ...
     zeta * sparsePrior(present_Js(:,:,3)) + ...
     xi * edgePrior(present_Js(:,:,1), 1, 0) + ...
     xi * edgePrior(present_Js(:,:,2), 1, 0) + ...
     xi * edgePrior(present_Js(:,:,3), 1, 0) ;
%          theta * (sum(sum((present_A - A_est).^2)));

    disp(iter);
    iter = iter+1;
end

present_J = previous_J;
present_t = previous_t;
T = present_t;
%  T = guided_filter(present_t, rgb2gray(Orig_image), 0.003, 3);
%  for c = 1:3
%          present_J(:,:,c) = (Orig_image(:,:,c) - A_est(:,:,c))./(max(T, 0.1)) + A_est(:,:,c);
%  end

figure;
plot(obj_fns);
figure;
x = imfuse(Orig_image,present_J,'montage');
imshow(x);
figure; imshow(present_t);
figure; imshow(present_Js);
figure; imshowpair(present_J,Clean_image,'montage');


% imwrite(present_J,'Simulated Image Data/dehazed_out5.png');
% imwrite(present_t,'Simulated Image Data/tx_estimate_5.png');


a = sqrt(sum(sum(sum((present_J - Clean_image).^2)))/(size(present_J, 1)* size(present_J, 2)* size(present_J, 3)));

% end