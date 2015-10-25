-module(neuron).
-compile(export_all).
-include("records.hrl").

%Neuron module

gen(ExoSelf_PId,Node)->
	spawn(Node,?MODULE,loop,[ExoSelf_PId]).

loop(ExoSelf_PId) ->
	receive
		{ExoSelf_PId,{Id,Cx_PId,AF,Input_PIdPs,Output_PIds}} ->
			loop(Id,Cx_PId,AF,{Input_PIdPs,Input_PIdPs},Output_PIds,0)
	end.
%When gen/2 is executed it spawns the neuron element and immediately begins to wait for its initial state message.

loop(Id,Cx_PId,AF,{[{Input_PId,Weights}|Input_PIdPs],MInput_PIdPs},Output_PIds,Acc)->
	receive
		{Input_PId,forward,Input}->
			Result = dot(Input,Weights,0),
			loop(Id,Cx_PId,AF,{Input_PIdPs,MInput_PIdPs},Output_PIds,Result+Acc);
		{Cx_PId,get_backup}->
			Cx_PId ! {self(),Id,MInput_PIdPs},
			loop(Id,Cx_PId,AF,{[{Input_PId,Weights}|Input_PIdPs],MInput_PIdPs},Output_PIds,Acc);
		{Cx_PId,terminate}->
			ok
	end;
loop(Id,Cx_PId,AF,{[Bias],MInput_PIdPs},Output_PIds,Acc)->
	Output = neuron:AF(Acc+Bias),
	[Output_PId ! {self(),forward,[Output]} || Output_PId <- Output_PIds],
	loop(Id,Cx_PId,AF,{MInput_PIdPs,MInput_PIdPs},Output_PIds,0);
loop(Id,Cx_PId,AF,{[],MInput_PIdPs},Output_PIds,Acc)->
	Output = neuron:AF(Acc),
	[Output_PId ! {self(),forward,[Output]} || Output_PId <- Output_PIds],
	loop(Id,Cx_PId,AF,{MInput_PIdPs,MInput_PIdPs},Output_PIds,0).

dot([I|Input],[W|Weights],Acc) ->
	dot(Input,Weights,I*W+Acc);
dot([],[],Acc)->
	Acc.
%The neuron process waits for vector signals from all the processes that it’s connected from, taking the dot product of the input and weight vectors, and then adding it to the accumulator. Once all the signals from Input_PIds are received, the accumulator contains the dot product to which the neuron then adds the bias and executes the activation function on. After fanning out the output signal, the neuron again returns to waiting for incoming signals. When the neuron receives the {Cx_PId,get_backup} message, it forwards to the cortex its full MInput_PIdPs list, and its Id. Once the training/learning algorithm is added to the system, the MInput_PIdPs would contain a full set of the most recent and updated version of the weights.

tanh(Val)->
	math:tanh(Val).
%Though in this current implementation the neuron has only the tanh/1 function available to it, we will later extend the system to allow different neurons to use different activation functions.
