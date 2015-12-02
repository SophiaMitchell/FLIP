%+-------------------------------------------------------+%
%|                 Fuzzy MATLAB PONG v2.0                |%
%|                  by Sophia Mitchell                   |%
%|                                                       |%
%|             Original by David Buckingham              |%
%| a fast-paced two-player game inspired by Atari's Pong |%
%+-------------------------------------------------------+%

%v0.3
%fixed bug where ball bouncing off right or left wall caused goal.
%paddle height reduced.
%ball acceleration reduced.
%changed colors and aesthetics.
%increased winning score to 5.
%main figure is wider and less tall. no change to plot dimensions.

%v0.2
%fixed bug where ball gets 'stuck' along top or bottom wall.

function [] = pong04smart()

close all
clear all
clc

%----------------------CONSTANTS----------------------
%game settings
MAX_POINTS = 21;
START_DELAY = 1;

%movemment
FRAME_DELAY = .01; %animation frame duration in seconds, .01 is good.
MIN_BALL_SPEED = .8; %each round ball starts at this speed
MAX_BALL_SPEED = 2.8; %wont accelerate bast this, dont set too high or bugs.
BALL_ACCELERATION = 0.05; %how much ball accelerates each bounce.
PADDLE_SPEED = 1.3;
%B_FACTOR and P_FACTOR increase the ball's dx/dy, i.e. making it move
%more horizontaly and less vertically. When the ball bounces, B_FACTOR
%is used to calculate a small variance in the resulting ball vector.
%Lower values increases dx/dy. 1 seems to work well for B_FACTOR. When the
%ball hits a paddle, its new vector is the line connecting the center of
%the paddle to the center of the ball. x value of this vector is multiplied
%P_FACTOR. Higher P_FACTOR increases the ball's dx/dy after hitting
%a paddle. 2 seems to work well for P_FACTOR.
B_FACTOR = 1;
P_FACTOR = 2;
%Y_FACTOR is used to fix a bug where ball would get 'stuck' bouncing
%back and forth along the top or bottom wall. A collision with top or
%bottom wall causes a bounce where new dx is -(old dx). If old dx is 0 then
%new dx is 0 so ball never leaves wall. Y_FACTOR is added to dx when
%ball bounces off top or bottom wall. It should be small. 0.01 works well.
Y_FACTOR = 0.01;
%GOAL_BUFFER is distance beyond end of plot ball must travel to score a
%goal. if this is 0 or too small, goals can be scored by fast ball bouncing
%off right or left wall. Too high and angled goals will bounce back in
GOAL_BUFFER = 5;

%layout/structure
BALL_RADIUS = 1.5; %radius to calculate bouncing
WALL_WIDTH = 3;
FIGURE_WIDTH = 800; %pixels
FIGURE_HEIGHT = 480;
PLOT_W = 150; %width in plot units. this will be main units for program
PLOT_H = 100; %height
GOAL_SIZE = 100;
GOAL_TOP = (PLOT_H+GOAL_SIZE)/2;
GOAL_BOT = (PLOT_H-GOAL_SIZE)/2;
PADDLE_H = 18; %height
PADDLE_W = 3; %width
PADDLE = [0 PADDLE_W PADDLE_W 0 0; PADDLE_H PADDLE_H 0 0 PADDLE_H];
PADDLE_SPACE = 10; %space between paddle and goal

%appearance
FIGURE_COLOR = [.2, .5, .2]; %program background
AXIS_COLOR = [.9, .9, .4]; %the court
BALL_MARKER_SIZE = 10; %aesthetic, does not affect physics, see BALL_RADIUS
BALL_COLOR = [.1, .7, .1];
BALL_OUTLINE = [.7, 1, .7];
BALL_SHAPE = 'o';
PADDLE_LINE_WIDTH = 2;
WALL_COLOR = [0, 0, 0]; %format string for drawing walls
PADDLE_COLORA = [1, 0, 0];
PADDLE_COLORB = [0, 0, 1];
CENTERLINE_COLOR = [0, 0, 0]; %format string for centerline
PAUSE_BACKGROUND_COLOR = FIGURE_COLOR;
PAUSE_TEXT_COLOR = [1, 1, 1];
PAUSE_EDGE_COLOR = BALL_COLOR;
TITLE_COLOR = 'w';

%messages
PAUSE_WIDTH = 36; %min pause message width, DO NOT MODIFY, KEEP AT 36
MESSAGE_X = 38; %location of message displays. 38, 55 is pretty centered
MESSAGE_Y = 55;
MESSAGE_PAUSED = ['             GAME PAUSED' 10 10];
MESSAGE_INTRO = [...
  '             welcome to ' 10 10 ...
  '         FUZZY MATLAB PONG' 10 10 ...
  '     first to get ' num2str(MAX_POINTS) ' points wins!' 10 10 ...
  '    player 1 is a        player 2:' 10 ...
  '   fuzzy computer    use arrow keys' 10 10 ...
  ];
MESSAGE_CONTROLS = '  pause:(p)   reset:(r)   quit:(q)';

%----------------------VARIABLES----------------------
fig = []; %main program figure
quitGame = false; %guard for main loop. when true, program ends
paused = []; %true if game is paused
score = []; %1x2 vector holding player scores
winner = []; %normally 0. 1 if player1 wins, 2 if player2 wins
ballPlot = []; %main plot, includes ball and walls
paddle1Plot = []; %plot for paddle
paddle2Plot = [];
ballVector=[]; %normalized vector for ball movement
ballSpeed=[];
ballX = []; %ball location
ballY = [];
paddle1V = []; %holds either 0, -1, or 1 for paddle movement ######################### <---------------------------------------------------
paddle2V = [];
paddle1 = []; %2x5 matrix describing paddle, based on PADDLE
paddle2 = [];
new_traj = [];
current_pos = [];
think = false;
mvmnt = false;
scoredif = [];
timething = timer;
set(timething,'ExecutionMode','fixedRate','TimerFcn', @(x,y)refreshPlot, 'Period', FRAME_DELAY);

%-----------------------SUBROUTINES----------------------

%------------createFigure------------
%sets up main program figure
%plots ball, walls, paddles
%called once at start of program
  function createFigure
    %ScreenSize is a four-element vector: [left, bottom, width, height]:
    scrsz = get(0,'ScreenSize');
    fig = figure('Position',[(scrsz(3)-FIGURE_WIDTH)/2 ...
      (scrsz(4)-FIGURE_HEIGHT)/2 ...
      FIGURE_WIDTH, FIGURE_HEIGHT]);
    
    %register keydown and keyup listeners
    set(fig,'KeyPressFcn',@keyDown, 'KeyReleaseFcn', @keyUp);
    
    %figure can't be resized
    set(fig, 'Resize', 'off');
    axis([0 PLOT_W 0 PLOT_H]);
    axis manual;
    
    %set color for the court, hide axis ticks.
    set(gca, 'color', AXIS_COLOR, 'YTick', [], 'XTick', []);
    %set background color for figure
    set(fig, 'color', FIGURE_COLOR);
    hold on;
    
    %plot walls
    topWallXs = [0,0,PLOT_W,PLOT_W];
    topWallYs = [GOAL_TOP,PLOT_H,PLOT_H,GOAL_TOP];
    bottomWallXs = [0,0,PLOT_W,PLOT_W];
    bottomWallYs = [GOAL_BOT,0,0,GOAL_BOT];
    plot(topWallXs, topWallYs, '-', ...
      'LineWidth', WALL_WIDTH, 'Color', WALL_COLOR);
    plot(bottomWallXs, bottomWallYs, '-', ...
      'LineWidth', WALL_WIDTH, 'Color', WALL_COLOR);
    
    %draw lines on court
    centerline = plot([PLOT_W/2, PLOT_W/2],[PLOT_H, 0],'--');
    set(centerline, 'Color', CENTERLINE_COLOR);

    %plot ball, we'll set ball location in refreshPlot
    ballPlot = plot(0,0);
    set(ballPlot, 'Marker', BALL_SHAPE);
    set(ballPlot, 'MarkerEdgeColor', BALL_OUTLINE);
    set(ballPlot, 'MarkerFaceColor', BALL_COLOR);
    set(ballPlot, 'MarkerSize', BALL_MARKER_SIZE);
    
    %plot paddles, we'll set paddle locations in refreshPlot
    paddle1Plot = plot(0,0, '-', 'LineWidth', PADDLE_LINE_WIDTH);
    paddle2Plot = plot(0,0, '-', 'LineWidth', PADDLE_LINE_WIDTH);
    set(paddle1Plot, 'Color', PADDLE_COLORA);
    set(paddle2Plot, 'Color', PADDLE_COLORB);

  end

%------------newGame------------
%resets game to starting conditions.
%called from main loop at program start
%called from keydown when user hits 'r'
%called from checkGoal after someone wins
%sets some variables, calls reset game,
%and calls pauseGame with intro message
  function newGame  
    move_here = 50;
    winner = 0;
    score = [0, 0];
    paddle1V = 0; %velocity
    paddle2V = 0; %velocity
    paddle1 = [PADDLE(1,:)+PADDLE_SPACE; ...
      PADDLE(2,:)+((PLOT_H - PADDLE_H)/2)];
    paddle2 = [PADDLE(1,:)+ PLOT_W - PADDLE_SPACE - PADDLE_W; ...
      PADDLE(2,:)+((PLOT_H - PADDLE_H)/2)];
    resetGame;
    if ~quitGame; %incase we try to quit from winner message
      pauseGame([MESSAGE_INTRO, MESSAGE_CONTROLS]);
    end
  end

%------------resetGame------------
%resets ball location speed and direction
%resets title string to display scores
%called from newGame
%called from checkGoal after each goal
  function resetGame
    bounce([1-(2*rand), 1-(2*rand)]);
    ballSpeed=MIN_BALL_SPEED;
     ballX = PLOT_W/2;
     ballY = PLOT_H/2;
    %here 19 is the space between the scores
    titleStr = sprintf('%d / %d%19d / %d', ...
      score(1), MAX_POINTS, score(2), MAX_POINTS);
    t = title(titleStr, 'Color', TITLE_COLOR);
    set(t, 'FontName', 'Courier','FontSize', 15, 'FontWeight', 'Bold');
    refreshPlot;
    if ~quitGame; %make sure we don't wait to quit if use hit 'q'
      pause(START_DELAY);
    end
    current_pos = paddle1(2,:);
    Position = (paddle2(2,2)+paddle2(2,3))/2;
    if ballVector(1) < 0
        think = true;
    end
  end

%------------refreshPlot------------
%sets data in plots
%calls matlab's drawnow to refresh plots
%uses matlab pause to create animation frame
%called from main loop on every frame
  function refreshPlot
    set(ballPlot, 'XData', ballX, 'YData', ballY);
    set(paddle1Plot, 'Xdata', paddle1(1,:), 'YData', paddle1(2,:));
    set(paddle2Plot, 'Xdata', paddle2(1,:), 'YData', paddle2(2,:));
    current_pos = paddle1(2,:);
    Position = (paddle2(2,2)+paddle2(2,3))/2;
    drawnow;
   end

%------------moveBall------------
%calculates new ball location
%checks if it will hit any walls or paddles
%if it does, call bounce to change ball vector
%move ball to new location
%called from main loop on every frame
  function moveBall
    
    %paddle boundaries, useful for hit testing ball
    p1T = paddle1(2,1);
    p1B = paddle1(2,3);
    p1L = paddle1(1,1);
    p1R = paddle1(1,2);
    p1Center = ([p1L p1B] + [p1R p1T]) ./ 2;
    p2T = paddle2(2,1);
    p2B = paddle2(2,3);
    p2L = paddle2(1,1);
    p2R = paddle2(1,2);
    p2Center = ([p2L p2B] + [p2R p2T]) ./ 2;
    
    %while hit %calculate new vectors until we know it wont hit something
    %temporary new ball location, only apply if ball doesn't hit anything.
    newX = ballX + (ballSpeed * ballVector(1));
    newY = ballY + (ballSpeed * ballVector(2));
    
    %hit test right wall
    if (newX > (PLOT_W - BALL_RADIUS) ...
        && (ballY<GOAL_BOT+BALL_RADIUS || newY>GOAL_TOP-BALL_RADIUS))
      %hit right wall
      if (newY > GOAL_BOT && newY < GOAL_TOP - BALL_RADIUS)
        %hit bottom goal edge
        bounce([newX - PLOT_W, newY - GOAL_BOT]);
      elseif (newY < GOAL_TOP && newY > GOAL_BOT + BALL_RADIUS)
        %hit top goal edge
        bounce([newX - PLOT_W, newY - GOAL_TOP]);
      else
        %hit flat part of right wall
        bounce([-1 * abs(ballVector(1)), ballVector(2)]);
      end
      
      %hit test left wall
    elseif (newX < BALL_RADIUS ...
        && (newY<GOAL_BOT+BALL_RADIUS || newY>GOAL_TOP-BALL_RADIUS))
      %hit left wall
      if (newY > GOAL_BOT && newY < GOAL_TOP - BALL_RADIUS)
        %hit bottom goal edge
        bounce([newX, newY - GOAL_BOT]);
      elseif (newY < GOAL_TOP && newY > GOAL_BOT + BALL_RADIUS)
        %hit top goal edge
        bounce([newX, newY - GOAL_TOP]);
      else
        bounce([abs(ballVector(1)), ballVector(2)]);
      end
      
      %hit test top wall
    elseif (newY > (PLOT_H - BALL_RADIUS))
      %hit top wall
      bounce([ballVector(1), -1 * (Y_FACTOR + abs(ballVector(2)))]);
      %hit test bottom wall
    elseif (newY < BALL_RADIUS)
      %hit bottom wall,
      bounce([ballVector(1), (Y_FACTOR + abs(ballVector(2)))]);
      
      %hit test paddle 1
    elseif (newX < p1R + BALL_RADIUS ...
        && newX > p1L - BALL_RADIUS ...
        && newY < p1T + BALL_RADIUS ...
        && newY > p1B - BALL_RADIUS)
      bounce([(ballX-p1Center(1)) * P_FACTOR, newY-p1Center(2)]);
      
      %hit test paddle 2
    elseif (newX < p2R + BALL_RADIUS ...
        && newX > p2L - BALL_RADIUS ...
        && newY < p2T + BALL_RADIUS ...
        && newY > p2B - BALL_RADIUS)
      bounce([(ballX-p2Center(1)) * P_FACTOR, newY-p2Center(2)]);
      think = true;
      
    else
      %no hits
    end
    
    %move ball to new location
    ballX = newX;
    ballY = newY;  

  end

%------------checkGoal------------
%check ballX to see if ball passed through goal
%update score and see if anybody won
%call resetGame to reset ball location etc.
%if somebody won, then
%call pauseGame to display message, call newGame
%called from main loop on every frame
  function checkGoal
    goal = false;
    
    if ballX > PLOT_W + BALL_RADIUS + GOAL_BUFFER
      score(1) = score(1) + 1;
      if score(1) == MAX_POINTS;
        winner = 1;
      end
      goal = true;
    elseif ballX < 0 - BALL_RADIUS - GOAL_BUFFER
      score(2) = score(2) + 1;
      if score(2) == MAX_POINTS;
        winner = 2;
      end
      goal = true;
    end
    
    if goal %a goal was made
      pause(START_DELAY);
      resetGame;
      if winner > 0 %somebody won!
        pauseGame(['      PLAYER ' num2str(winner) ' IS THE WINNER!!!' 10])
        newGame;
      else %nobody won yet
      end
    end
  end

%------------pauseGame------------
%%sets paused variable to true
%starts a while loop guarded by pause variable
%displays provided string message
%called from newGame at game start
%called from keyDown when user hits 'p'
%called from checkGoal when someone scores
  function pauseGame(input)
    paused = true;
    str = '      hit any key to continue...';
    spacer = 1:PAUSE_WIDTH;
    spacer(:) = uint8(' ');
    while paused
      printText = [spacer 10 input 10 str 10];
      h = text(MESSAGE_X,MESSAGE_Y,printText);
      set(h, 'BackgroundColor', PAUSE_BACKGROUND_COLOR)
      set(h, 'Color', PAUSE_TEXT_COLOR)
      set(h,'EdgeColor',PAUSE_EDGE_COLOR);
      set(h, 'FontSize',5,'FontName','Courier','LineStyle','-','LineWidth',1);
      pause(FRAME_DELAY)
      delete(h);
    end
  end

%------------unpauseGame------------
%sets paused to false
%called from keyDown when user hits any key
  function unpauseGame()
    paused = false;
  end

%------------bounce------------
%takes input vector as argument
%increases dx/dy for more horizontal movement
%normalizes vector sets as new ball vector
%accelerates ball
%called by moveBall whenever ball hits something
  function bounce (tempV)
    %increase dx by a random amount
    %helps keep the ball moving more horizontally than vertically.
    tempV(1) = tempV(1) * (B_FACTOR + 1);
    %normalize vector
    tempV = tempV ./ (sqrt(tempV(1)^2 + tempV(2)^2));
    ballVector = tempV;
    %just to make things interesting, bouncing accelerates ball
    if (ballSpeed + BALL_ACCELERATION < MAX_BALL_SPEED)
      ballSpeed = ballSpeed + BALL_ACCELERATION;
    end
  end

%------------movePaddles------------
%uses paddle velocity set paddles
%called from main loop on every frame
  function movePaddles
          
    if (ballVector(1) < 0) && (ballX > 124.9 && ballX < 125.1)
        think = true;
    %elseif (ballVector(1) < 0) && (ballX > 98 && ballX < 102)
    %    think = true;
    elseif (ballVector(1) < 0) && (ballX > 74.85 && ballX < 75.1)
        think = true;
    elseif (ballVector(1) < 0) && (ballX > 73.5 && ballX < 74.85) && (ballSpeed > 1.6)
        think = true;
    elseif(ballVector(1) < 0) && (ballX > 58 && ballX < 62)
        think = true;
    elseif(ballVector(1) < 0) && (ballX > 49.85 && ballX < 50.1)
        think = true;
    %elseif(ballVector(1) < 0) && (ballX > 38 && ballX < 42)
    %    think = true;
    elseif(ballVector(1) < 0) && (ballX > 29.85 && ballX < 30.1)
        think = true;
    elseif (ballVector(1) < 0) && (ballX > 28.5 && ballX < 29.85) && (ballSpeed > 1.6)
        think = true;
    %elseif (ballVector(1) < 0) && (ballX > 23 && ballX < 27)
    %    think = true;
    end
    %set new paddle y locations  
    fuzzypaddle;
    
    paddle1(2,:) = paddle1(2,:) + (PADDLE_SPEED * paddle1V);
    paddle2(2,:) = paddle2(2,:) + (PADDLE_SPEED * paddle2V);
    
    
    %if paddle out of bounds, move it in bounds
    if paddle1(2,1) > PLOT_H
      paddle1(2,:) = PADDLE(2,:) + PLOT_H - PADDLE_H;
    elseif paddle1(2,3) < 0
      paddle1(2,:) = PADDLE(2,:);
    end
    if paddle2(2,1) > PLOT_H
      paddle2(2,:) = PADDLE(2,:) + PLOT_H - PADDLE_H;
    elseif paddle2(2,3) < 0
      paddle2(2,:) = PADDLE(2,:);
    end
  end

%------------keyDown------------
%listener registered in createFigure
%listens for input
%sets appropriate variables and calls functions
  function keyDown(src,event) %#ok<INUSL>
    switch event.Key
      
      %case 'a'
      %  paddle1V = 1;
      %case 'z'
      %  paddle1V = -1;
      
      case 'uparrow'
        paddle2V = 1;
      case 'downarrow'
        paddle2V = -1;
      case 'p'
        if ~paused
          pauseGame([MESSAGE_PAUSED MESSAGE_CONTROLS]);
        end
      case 'r'
        newGame;
      case 'q'
        unpauseGame;
        quitGame = true;
    end
    unpauseGame;
  end

%------------keyUp------------
%listener registered in createFigure
%used to stop paddles on keyup
  function keyUp(src,event) %#ok<INUSL>
    switch event.Key
      
      %case 'a'
      %  if paddle1V == 1
      %    paddle1V = 0;
      %  end
      %case 'z'
      %  if paddle1V == -1
      %    paddle1V = 0;
      %  end
        
      case 'uparrow'
        if paddle2V == 1
          paddle2V = 0;
        end
      case 'downarrow'
        if paddle2V == -1
          paddle2V = 0;
        end
    end
  end

%----------------------MAIN SCRIPT----------------------
createFigure;
newGame;
start(timething);
%--------------Necessary variables--------------------
move_here = [];
ballSpeedt = [];
new_traj = [];
use_this = [];
think = false;
m = [];
b = [];
y = [];
x = [];
b_p = [];
traj_here = [];
Open = [];
Position = [];
inertia = [];
correct = [];
MyPosition = [];
game = [];
mvmnt = false;

type = readfis('gametype');
aware = readfis('oppsingle');
strat = readfis('frontstrat');
move = readfis('pdlemvmnt2');

while ~quitGame
  moveBall;
  movePaddles;
  checkGoal;
  pause(.001);
end
stop(timething);
delete(timething);
close(fig);

%################-FUZZY INTELLIGENCE-######################



%----------recalcM----------
%does the same thing as bounce, but for the AI
%called by fuzzy whenever ball trajectory hits something
  function recalcM (tempV)
    tempV = [tempV(1)*(B_FACTOR + 1),(-1)*(Y_FACTOR + tempV(2))];
    tempV = tempV ./ (sqrt(tempV(1)^2 + tempV(2)^2));
    use_this = tempV;
    new_traj = tempV;
    if ((ballSpeedt + BALL_ACCELERATION) < MAX_BALL_SPEED)
      ballSpeedt = ballSpeed + BALL_ACCELERATION;
    end
  end

%------fuzzypaddle-------------
%moves fuzzy paddle to defensive position
%takes in 
%returns paddle1V

    function fuzzypaddle()
                
        if ballVector(1)>0
            move_here = 50;
        end
        
    new_traj = ballVector;
    ballSpeedt=ballSpeed;
    inertia = paddle2V;
    MyPosition = (current_pos(2)+current_pos(3))/2;
    
    %find current m
    m =(new_traj(2)*ballSpeedt) / (new_traj(1)*ballSpeedt);
    
    %(1) find b at current position
    b = ballY - (m*ballX);
    
    while think == true     
        
        %(2) find y at x = 2
        y = (m*10)+b;

        %(3) is y within limits?
        if (0<y && y<100)

            %(4) if yes, move there.
            traj_here = y;
            think = false;
            mvmnt = true;

        %(5 a) if y was bigger than 100, y now equals 100.
        elseif y>100
            y = 100;

        %(5 b) if y was smaller than 0, y now equals 0.
        elseif y<0
            y = 0;
        end
        %(6) find x at bounce point (where y is either 100 or 0. use same b and m)
        x = (y-b)/m;

        %(7) new (x,y) is considered bounce point
        b_p = [x y];

        %(8) find new m and b at bounce point.
        recalcM(new_traj);
        m = (use_this(2)*ballSpeedt)/(use_this(1)*ballSpeedt);
        b = b_p(2) - (m*b_p(1));

        %(9) go back to 2.
    end
    while mvmnt == true
        
        scoredif = score(2)-score(1);
        
        %classify the type of game
        
        game = evalfis( [scoredif; ballSpeed], type);
        
        %find where the other person is...
        
        Open = evalfis([Position; inertia], aware);
    
        %decide strategy
        
        correct = evalfis([MyPosition; Open; game], strat); 
    
        %point you want the center to be is corrected for section that will hit
        %the ball.
        move_here = traj_here - correct;
        mvmnt = false;
    end
    
    difference = move_here - ((current_pos(2)+current_pos(3))/2);
   
    if(isempty(difference))
        difference = 0;
    end
    
    paddle1V = evalfis(difference, move);
        
    end
end

