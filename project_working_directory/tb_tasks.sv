
package tb_tasks;

    // Initialize task
    task automatic initialize(ref clk, RST_n, send_cmd);
        begin
            clk = 0;
            RST_n = 0;
            
            send_cmd = 0;
            
            @(negedge clk);
            RST_n = 1;
            
        end
    endtask
    
    // Sending command task
    task automatic SendCmd(input [15:0] host_cmd, ref clk, send_cmd, ref logic[15:0] cmd);
        begin			
            @(negedge clk);
            cmd = host_cmd;
            
            // Pulsing send_cmd
            @(negedge clk);
            send_cmd = 1;
            
            @(negedge clk);
            send_cmd = 0;
            
        end
    endtask
    
    // Waiting for NEMO_setup
    task automatic wait_for_NEMO_setup(ref NEMO_setup, clk);
        fork
            begin: timeout1
                repeat(1000000) @(posedge clk);
                $display("ERROR! Timed out while waiting for NEMO_setup");
                $stop();
            end
            // iPHYS.iNEMO.NEMO_setup
            begin
                @(posedge NEMO_setup); // Checking for NEMO_setup flag
                $display("PASSED! NEMO_setup asserted.");			
                disable timeout1;
            end
        join
    endtask
    
    
    // Waiting for cal_done signal
    task automatic wait_for_cal_done(ref cal_done, clk);
        fork
            begin: timeout2
                repeat(1000000) @(posedge clk);
                $display("ERROR! Timed out while waiting for cal_done");
                $stop();
            end
            begin
                @(posedge cal_done);          // Checking for cal_done flag
                $display("PASSED! cal_done asserted.");	
                disable timeout2;
            end
        join
    endtask
    
    // checking for correct resp
    task automatic ChkPosAck(ref resp_rdy,  clk ,ref logic[7:0] resp );
        fork
            begin: timeout
                repeat(50000000) @(posedge clk);
                $display("ERROR! Timed out while waiting for resp_rdy");
                $stop();
            end
            begin
                @(posedge resp_rdy);
                if (!(resp == 8'ha5))begin
                    $display("Wrong resp");
                end
                $display("PASSED! Postive acknowledge of resp");	
                disable timeout;
            end
        join
    endtask
    
    // Heading check
    task automatic chkHeading(ref clk, ref logic signed[11:0]desired_heading, ref logic signed[11:0] heading );
        fork
            begin: wait_heading
                repeat(5000000)@(posedge clk);
                $display("timed out waiting for heading to converge to desired_heading");
                $stop();
            end
            // iDUT.iCMD.desired_heading-iDUT.heading
            begin
            	if(desired_heading == 12'h7ff) begin 
		    	if(heading[11]) begin
		    		heading = ~heading+1'b1;
		    	end 
		   end
	        if(((desired_heading-heading) < 100) && ((desired_heading-heading) > -100)) begin
	            disable wait_heading;
	            $display("PASSED! Heading Converged");
	        end
            end
        join
    endtask
    
    // Check for Center IR sensor
    task automatic chkCntrlIR(input int moves, ref clk, cntrIR);
        fork
        begin: timeout
            repeat(10000000) @(posedge clk);
            $display("ERROR! Timed out while waiting for Center IR");
            $stop();
        end
        begin
            repeat(moves)@(posedge cntrIR);
            $display("PASSED! CntrlIR fired!");			
            disable timeout;
        end
        join
    endtask
    
    // Checking X index
    task automatic chkX(input int clksToWait,input logic[14:0] expected_x, ref logic[14:0] xx, ref clk );

       
        fork
            begin: checkXval
                repeat(clksToWait)@(posedge clk);
                $display("timed out waiting for xx to converge to expected_x");
                $stop();
            end
            begin
                if(($signed($signed(expected_x)-$signed(xx)) < $signed(15'h0300) && ($signed($signed(expected_x)-$signed(xx)) > $signed(-15'h0300))))begin
                    disable checkXval;
                    $display("XX Converged");
                end
            end
        join
      endtask
      
      
    // Checking Y index
    task automatic chkY(input int clksToWait,input logic[14:0] expected_y, ref logic[14:0] yy, ref clk );

        fork
            begin: checkyval
                repeat(clksToWait)@(posedge clk);
                $display("timed out waiting for yy to converge to expected_y");
                $display("%4h", $signed($signed(expected_y)-$signed(yy)));
                
                $stop();
            end
            // iDUT.iCMD.desired_heading-iDUT.heading
            begin
                if(($signed($signed(expected_y)-$signed(yy)) < $signed(15'h0300) && ($signed($signed(expected_y)-$signed(yy)) > $signed(-15'h0300))))begin
                    disable checkyval;
                    $display("YY Converged");
                end
            end
        join

    endtask
    
    // Calculating xx and yy offsets
	    function signed [2:0] off_x(input [7:0] try);
	    ///////////////////////////////////////////////////
		// Consider writing a function that returns a the x-offset
		// the Knight will move given the encoding of the move you
		// are going to try.  Can also be useful when backing up
		// by passing in last move you did try, and subtracting 
		// the resulting offset from xx
		/////////////////////////////////////////////////////
		    off_x = (try[0] | try[5]) ? 3'b001 :  // 1
		        (try[7] | try[6]) ? 3'b010 :  // 2
		        (try[2] | try[3]) ? 3'b110 :  // -2
		        (try[1] | try[4]) ? 3'b111 :  // -1
		        3'b000;  // Default case (if none of the conditions are true)
		return off_x;
	  endfunction
  
	  function signed [2:0] off_y(input [7:0] try);
	    ///////////////////////////////////////////////////
		// Consider writing a function that returns a the y-offset
		// the Knight will move given the encoding of the move you
		// are going to try.  Can also be useful when backing up
		// by passing in last move you did try, and subtracting 
		// the resulting offset from yy
		/////////////////////////////////////////////////////
		    off_y = (try[2] | try[7]) ? 3'b001 :  // 1
		        (try[1] | try[0]) ? 3'b010 :  // 2
		        (try[4] | try[5]) ? 3'b110 :  // -2
		        (try[3] | try[6]) ? 3'b111 :  // -1
		        3'b000;  // Default case (if none of the conditions are true)
		return off_y;
	  endfunction
	    
    
    
	// Checks if tour logic and command is integrated and performs as expected    
        task automatic tour_start(input int clks2wait,ref clk, ref logic [7:0]resp, ref logic resp_rdy,  ref logic[14:0] xx,ref logic[14:0] yy, ref [7:0]move, ref logic signed[16:0] omega_sum, ref logic signed [19:0] heading_robot);
    
	    fork
	    	begin: Check_tour
	    		 repeat(clks2wait)@(posedge clk);
	    		 $display("Incorrect tour");
	    		 $stop();
	    	end
	    	begin
	    		integer i;
			    logic [14:0]expected_x; // Register for expected x val
			    logic [14:0]expected_y; // Register for expected y val
	    		
                // Waiting for resp 5A, indicating start of tour
	    		wait (resp == 8'h5a);
	    		$display("Tour started!");
	    	
	    		for(i = 0; i < 48; i = i + 1) begin: break_for
	    		
	    			@ (posedge clk);
		    		expected_x = $signed($signed(xx) + ($signed(16'h1000) * $signed(off_x(move)))); // Calculating expected x based off move
		    		expected_y = $signed($signed(yy) + ($signed(16'h1000) * $signed(off_y(move))));	// Calculating expected y based off move

                    // Checking for xx and yy at posedge resp_rdy
                    @(posedge resp_rdy);
		    		if ( i % 2 == 1) begin
		    			chkX(.clksToWait(1000000),.expected_x(expected_x),  .clk(clk), .xx(xx) );
		    		end
		    		else begin
		    			chkY(.clksToWait(1000000),.expected_y(expected_y),  .clk(clk), .yy(yy) );
		    		end
	    	
		    		
	    		end  
                
                if(!(resp === 8'ha5)) begin
                    $display("wrong response");
                    $stop();
                end
                	
	    		$display("PASSED! Tour done!");
	    		disable Check_tour;
	    		
	    	end
            
	    join
    
    endtask
   
    
    
    
    
    
    
    
    
endpackage
