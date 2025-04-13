%%%%%   TIRE SCRUB ESTIMATION  %%%%%

clc;
clear all;
close all;

% Defining parameters(all should be in SI)
C_tau = 3.5e7; % Stiffness constant Cτ (N/m^3) 
a = 0.07;  % half-length of the contact patch in x-direction
a_minus = -a;
w = 0.101;  % half-width of the contact patch in y-direction
w_minus = -w;
xc = 0.03; % x-coordinate of center of rotation (m)
yc = 0.0; % y-coordinate of center of rotation (m)
mu_adhesive = 0.55;         % Maximum friction coefficient
mu_s = 0.44;                % Minimum friction coefficient

%load desired load_distribution file
load_griddata = load("xquartic_ytaperedoff.mat");
x_matrix = load_griddata.x_matrix;
y_matrix = load_griddata.y_matrix;
y_matrix = flipud(y_matrix);        %lowest brush avilable on the bottom left corner (-70,-101)
z_matrix = load_griddata.total_load_distribution;

%reformulizing the z_matrix
%ensuring the boundary conditions 
for ix = 1:102
    for iy = 1:71
        if z_matrix(ix,iy) < 0
            z_matrix(ix,iy) = 0;
        else 
            z_matrix(ix,iy) = z_matrix(ix,iy);
        end
    end
end

%load craig data
load_craig = load("hal_2018-12-12_ac.mat");

n = 1:length(load_craig.t);  %length(load_craig.t), 10001:12000; FOR 22 to 24 secs  NO OF DESIRED ITERATION POINT

%loading experimental data from craig
left_steering_angle = load_craig.y(:,99);

left_steering_angle = left_steering_angle(n);
right_steering_angle = load_craig.y(:,100);
time_sec = load_craig.t;
time_sec = time_sec(n);


% Added minus sign to get the exact behaviour as stated in the paper
left_steering_torques = -load_craig.y(:,116);
left_steering_torques = left_steering_torques(n);
right_steering_torques = load_craig.y(:,117);
right_steering_torques = right_steering_torques(n);

% Intializing variable needed for the main for loop
delta_dot_gradient = gradient(left_steering_angle) ./ gradient(time_sec);
% load_delta_dot = load("butter_filtered_signal_99.mat");
% delta_dot_gradient = load_delta_dot.filtered_steering_rate;
% delta_dot_gradient = delta_dot_gradient(n);
window_size = 20;        %Resigned the code, Now you can use both, window size and xi as a same integer
d_t = time_sec(window_size);        %time difference between each window
x_values = linspace(a_minus,a,71);
y_values = linspace(w_minus,w,102);
brush_distance = sqrt((x_matrix - xc).^2 + (y_matrix - yc).^2);
brush_stiff_factor = C_tau .* brush_distance;
Tau_b = zeros(size(x_matrix,1),size(x_matrix,2),length(time_sec));
tau_b = zeros(size(x_matrix,1),size(x_matrix,2),length(time_sec));
integrand = zeros(size(x_matrix,1),size(x_matrix,2),length(time_sec));
T = zeros(1,length(time_sec));
xi = 20;



% Intrgral of the delta_dot
st_angle = zeros(1,length(time_sec));
for t = 1:length(time_sec)
    if t>window_size
        st_angle(t) = trapz(time_sec(t-window_size:t),delta_dot_gradient(t-window_size:t));
    elseif t == 1
        st_angle(t) = delta_dot_gradient(t) * d_t;          % can,t do the integration of a scalar, eithzer asssume zero or multiply with delta t
    else     
        st_angle(t) = trapz(time_sec(1:t),delta_dot_gradient(1:t));
    end
end

%Main for loop
for t=1:length(time_sec)

    for ix = 1:size(x_matrix,1)
        for iy = 1:size(y_matrix,2)
            if t>window_size
                Tau_b(ix,iy,t) = tau_b(ix,iy,t-xi) + brush_stiff_factor(ix,iy) * st_angle(t);             %  tau_b(ix,iy,t-window_size) + brush_stiff_factor(ix,iy) * st_angle(t); 
            else
                Tau_b(ix,iy,t) = brush_stiff_factor(ix,iy) * st_angle(t); 
            end

            if Tau_b(ix,iy,t) >= mu_adhesive * z_matrix(ix,iy)
                tau_b(ix,iy,t) = mu_s * z_matrix(ix,iy);
                integrand(ix,iy,t) = tau_b(ix,iy,t) * brush_distance(ix,iy);
            elseif Tau_b(ix,iy,t) <= -mu_adhesive * z_matrix(ix,iy)
                tau_b(ix,iy,t) = -mu_s * z_matrix(ix,iy);
                integrand(ix,iy,t) = tau_b(ix,iy,t) * brush_distance(ix,iy);
            elseif abs(Tau_b(ix,iy,t)) <= mu_adhesive *z_matrix(ix,iy)
                tau_b(ix,iy,t) = Tau_b(ix,iy,t);
                integrand(ix,iy,t) = tau_b(ix,iy,t) * brush_distance(ix,iy);
            end
        end
    end
    T(t) = trapz(y_values,trapz(x_values,integrand(:,:,t),2));
end

%% Figures


h1 = figure('Name','Steering Torque Vs Time fig filtered');
plot(time_sec,T,'r','DisplayName','Estimated left torque')
hold on
plot(time_sec,left_steering_torques,'g','DisplayName','Left steer torque','LineStyle',':')
hold off
xlabel('Time(sec)');
ylabel('Steering Torque(Nm)'); 
legend('show')
title('Estimated Tire Scrub Torque');
grid on;
 
% h2 = figure('Name','Left Steering Angle Vs Time');
% plot(time_sec,left_steering_angle)
% xlabel('time (sec)')
% ylabel('Left steering angle (rad)')
% title('Steering Angle Behaviour')
% grid on;
 
% h3 = figure('Name','delta_dot Vs Time');
% plot(time_sec,delta_dot_gradient)
% xlabel('time (sec)')
% ylabel('delta_dot (rad/sec)')
% title(sprintf('Steering rate behaviour at xi = %.f and window size = %.f',xi,window_size+1))
% grid on
 
% h4 = figure('Name','Steering Torque Vs Steering Angle');
% plot(rad2deg(left_steering_angle),T,'r','DisplayName','Estimated left torque')
% hold on
% plot(rad2deg(left_steering_angle),left_steering_torques,'g','DisplayName','Actual Left steer torque','LineStyle',':')
% hold off
% xlabel('steering angle (deg)');
% ylabel('Steering Torque(Nm)'); 
% legend('show')
% grid on;
 
