%%
%% Copyright (C) 2010 by Moritz Tenorth
%%
%% This program is free software; you can redistribute it and/or modify
%% it under the terms of the GNU General Public License as published by
%% the Free Software Foundation; either version 3 of the License, or
%% (at your option) any later version.
%%
%% This program is distributed in the hope that it will be useful,
%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%% GNU General Public License for more details.
%%
%% You should have received a copy of the GNU General Public License
%% along with this program.  If not, see <http://www.gnu.org/licenses/>.
%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% dependencies

% Semweb library for OWL/RDF access
:- register_ros_package(semweb).


% TUM utilities library
:- register_ros_package(ias_prolog_addons).
:- use_module(library('classifiers')).
:- use_module(library('jython')).
:- use_module(library('util')).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% parse OWL files, register name spaces
:- owl_parser:owl_parse('/work/ros/tumros-internal/stacks/knowrob/ias_knowledge_base/owl/owl.owl', false, false, true).
:- owl_parser:owl_parse('/work/ros/tumros-internal/stacks/knowrob/ias_knowledge_base/owl/knowrob.owl', false, false, true).

:- rdf_db:rdf_register_ns(rdfs,    'http://www.w3.org/2000/01/rdf-schema#',     [keep(true)]).
:- rdf_db:rdf_register_ns(owl,     'http://www.w3.org/2002/07/owl#',            [keep(true)]).
:- rdf_db:rdf_register_ns(knowrob, 'http://ias.cs.tum.edu/kb/knowrob.owl#',     [keep(true)]).


% convenience: set some Prolog flags in order *not to* trim printed lists with [...]
:- set_prolog_flag(toplevel_print_anon, false).
:- set_prolog_flag(toplevel_print_options, [quoted(true), portray(true), max_depth(0), attributes(portray)]).

:- set_prolog_flag(float_format, '%.12g').


:-  rdf_meta
    storagePlaceFor(r,r),
    storagePlaceForBecause(r,r,r).


  storagePlaceFor(St, ObjT) :-
    storagePlaceForBecause(St, ObjT, _).

  % two instances
  storagePlaceForBecause(St, Obj, ObjT) :-
    owl_subclass_of(StT, knowrob:'StorageConstruct'),
    owl_restriction_on(StT, restriction(knowrob:'typePrimaryFunction-StoragePlaceFor', some_values_from(ObjT))),
    owl_individual_of(Obj, ObjT),
    owl_individual_of(St, StT).

  % obj type, storage instance
  storagePlaceForBecause(St, ObjType, ObjT) :-
    owl_subclass_of(StT, knowrob:'StorageConstruct'),
    owl_restriction_on(StT, restriction(knowrob:'typePrimaryFunction-StoragePlaceFor', some_values_from(ObjT))),
    owl_individual_of(St, StT),
    owl_subclass_of(ObjType, ObjT).




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% utility to generate unique instance identifiers

:- assert(instance_nr(0)).
rdf_instance_from_class(Class, Instance) :-

  % retrieve global index
  instance_nr(Index),

  % create instance from type
  ((concat_atom(List, '#', Class),length(List,Length),Length>1) -> (
    % Class is already a URI
    T=Class
  );(
    atom_concat('http://ias.cs.tum.edu/kb/knowrob.owl#', Class, T)
  )),
  atom_concat(T, Index, Instance),
  rdf_assert(Instance, rdf:type, T),

  % update index
  retract(instance_nr(_)),
  Index1 is Index+1,
  assert(instance_nr(Index1)).



:-  rdf_meta
    holds_tt(:,t).

% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
% KnowRob-Base: holds() and related predicates
% 


%% holds_tt(+Goal, [+Start, +End]) is nondet.
%
% General definition of holds_tt that uses holds(..) to check if a relation
% holds throughout a time span (i.e. for each time point during the time span)
%
% @param Goal  The goal that is to be checked
% @param Start Start time of the time span under consideration
% @param End   End time of the time span under consideration
%
holds_tt(Goal, [Start, End]) :-

    rdf_assert(knowrob:'holds_tt', rdf:type, knowrob:'TimeInterval'),
    rdf_assert(knowrob:'holds_tt', knowrob:startTime, Start),
    rdf_assert(knowrob:'holds_tt', knowrob:endTime,   End),

    holds(Goal, Start),
    holds(Goal, End),

    % find all detections of the objects at hand
    arg(1, Goal, Arg1),arg(2, Goal, Arg2),
    findall([D_i,Arg1], ( (rdf_has(D_i, knowrob:objectActedOn, Arg1);rdf_has(D_i, knowrob:objectActedOn, Arg2)),
                           rdfs_individual_of(D_i,  knowrob:'MentalEvent')), Detections),

      forall( ( member(D_O, Detections), nth0(0, D_O, Detection),
                rdf_triple(knowrob:startTime, Detection, DStT),
                rdf_triple(knowrob:temporallySubsumes, knowrob:'holds_tt', DStT) ),
              holds(Goal, DStT) ),

    rdf_retractall(knowrob:'holds_tt', _, _).



%% get_timepoint(-T) is det.
%
% Create a timepoint-identifier for the current time
%
% @param T TimePoint instance identifying the current time stamp
%
get_timepoint(T) :-
  set_prolog_flag(float_format, '%.12g'),
  get_time(Ts),
  atom_concat('http://ias.cs.tum.edu/kb/knowrob.owl#timepoint_', Ts, T),
  rdf_assert(T, rdf:type, knowrob:'TimePoint').

%% get_timepoint(+Diff, -T) is det.
%
% Create a timepoint-identifier for the current time +/- Diff
%
% @param Diff Time difference to the current time
% @param T    TimePoint instance identifying the current time stamp
%
get_timepoint(Diff, Time) :-

  get_time(Ts),

  ((atom_concat('+', Dunit, Diff), atom_concat(DiffSeconds, 's', Dunit),term_to_atom(A, DiffSeconds)) -> (T is Ts + A) ;
   (atom_concat('+', Dunit, Diff), atom_concat(DiffMinutes, 'm', Dunit),term_to_atom(A, DiffMinutes)) -> (T is Ts + 60.0 * A) ;
   (atom_concat('+', Dunit, Diff), atom_concat(DiffHours,   'h', Dunit),term_to_atom(A, DiffHours))   -> (T is Ts + 3600.0 * A) ;

   (atom_concat('-', Dunit, Diff), atom_concat(DiffSeconds, 's', Dunit),term_to_atom(A, DiffSeconds)) -> (T is Ts - A) ;
   (atom_concat('-', Dunit, Diff), atom_concat(DiffMinutes, 'm', Dunit),term_to_atom(A, DiffMinutes)) -> (T is Ts - 60.0 * A) ;
   (atom_concat('-', Dunit, Diff), atom_concat(DiffHours,   'h', Dunit),term_to_atom(A, DiffHours))   -> (T is Ts - 3600.0 * A) ),


  atom_concat('http://ias.cs.tum.edu/kb/knowrob.owl#timepoint_', T, Time),
  rdf_assert(Time, rdf:type, knowrob:'TimePoint').



%% latest_detection_of_instance(+Object, -LatestDetection) is nondet.
%
% Get the lastest detection of the object instance Object
%
% A detection is an instance of MentalEvent, i.e. can be a perception
% process as well as an inference result
%
% @param Object          An object instance
% @param LatestDetection Latest MentalEvent associated with this instance
%
latest_detection_of_instance(Object, LatestDetection) :-

    findall([D_i,Object,St], (rdf_has(D_i, knowrob:objectActedOn, Object),
                              rdfs_individual_of(D_i,  knowrob:'MentalEvent'),
                              rdf_triple(knowrob:startTime, D_i, StTg),
                              rdf_split_url(_, StTl, StTg),
                              atom_concat('timepoint_', StTa, StTl),
                              term_to_atom(St, StTa)), Detections),

    predsort(compare_object_detections, Detections, Dsorted),

    % compute the homography for the newest perception
    nth0(0, Dsorted, Latest),
    nth0(0, Latest, LatestDetection).



%% latest_detection_of_type(+Type, -LatestDetection) is nondet.
%
% Get the lastest detection of an object of type Type
%
% A detection is an instance of MentalEvent, i.e. can be a perception
% process as well as an inference result
%
% @param Object          An object type
% @param LatestDetection Latest MentalEvent associated with any instance of this type
%
latest_detection_of_type(Type, LatestDetection) :-

    findall([D_i,Object,St], (rdfs_individual_of(Object, Type),
                              rdf_has(D_i, knowrob:objectActedOn, Object),
                              rdfs_individual_of(D_i,  knowrob:'MentalEvent'),
                              rdf_triple(knowrob:startTime, D_i, StTg),
                              rdf_split_url(_, StTl, StTg),
                              atom_concat('timepoint_', StTa, StTl),
                              term_to_atom(St, StTa)), Detections),

    predsort(compare_object_detections, Detections, Dsorted),

    % compute the homography for the newest perception
    nth0(0, Dsorted, Latest),
    nth0(0, Latest, LatestDetection).


%% latest_perception_of_type(+Type, -LatestPerception) is nondet.
%
% Get the lastest perception of an object of type Type
%
% @param Object          An object type
% @param LatestPerception Latest MentalEvent associated with any instance of this type
%
latest_perception_of_type(Type, LatestPerception) :-

    findall([P_i,Object,St], (rdfs_individual_of(Object, Type),
                              rdf_has(P_i, knowrob:objectActedOn, Object),
                              rdfs_individual_of(P_i,  knowrob:'VisualPerception'),
                              rdf_triple(knowrob:startTime, P_i, StTg),
                              rdf_split_url(_, StTl, StTg),
                              atom_concat('timepoint_', StTa, StTl),
                              term_to_atom(St, StTa)), Perceptions),

    predsort(compare_object_detections, Perceptions, Psorted),

    % compute the homography for the newest perception
    nth0(0, Psorted, Latest),
    nth0(0, Latest, LatestPerception).


%% latest_perceptions_of_types(+Type, -LatestPerceptions) is nondet.
%
% Get the lastest perceptions of all objects of type Type
%
% @param Object          An object type
% @param LatestPerceptions Latest MentalEvents associated with instances of this type
%
latest_perceptions_of_types(Type, LatestPerceptions) :-

    findall(Obj, rdfs_individual_of(Obj, Type), Objs),

    findall(LatestDetection,
            ( member(Object, Objs),
              latest_detection_of_instance(Object, LatestDetection),
              rdfs_individual_of(LatestDetection, knowrob:'VisualPerception') ),
            LatestPerceptions).



%% latest_inferred_object_set(-Object) is nondet.
%
% Ask for the objects inferred in the last inference run
%
% @param Objects   Set of object instances inferred in the latest inference run
%
latest_inferred_object_set(Objects) :-

    findall([D_i,_,St],  (rdfs_individual_of(D_i,  knowrob:'Reasoning'),
                          rdf_has(Inf, knowrob:probability, InfProb),
                          term_to_atom(Prob, InfProb),
                          >(Prob, 0),
                          rdf_triple(knowrob:startTime, D_i, StTg),
                          rdf_split_url(_, StTl, StTg),
                          atom_concat('timepoint_', StTa, StTl),
                          term_to_atom(St, StTa)), Inferences),

    predsort(compare_object_detections, Inferences, Psorted),

    % compute the newest perception
    nth0(0, Psorted, Latest),
    nth0(0, Latest, LatestInf),

    % find other inferences performed at the same time
    findall(OtherInf, (rdf_has(LatestInf, knowrob:'startTime', St), rdf_has(OtherInf, knowrob:'startTime', St)), OtherInfs),

    predsort(compare_inferences_by_prob, OtherInfs, SortedInfs),

    findall(Obj, (member(Inf, SortedInfs), rdf_has(Inf, knowrob:'objectActedOn', Obj)), Objects).


%% latest_inferred_object_types(-ObjectTypes) is nondet.
%
% Ask for the object types inferred in the last inference run
%
% @param ObjectTypes   Set of object types inferred in the latest inference run
%
latest_inferred_object_types(ObjectTypes) :-

    latest_inferred_object_set(Objects),
    findall(ObjT, (member(Obj, Objects), rdf_has(Obj, rdf:type, ObjT)), ObjectTypes).




%% object_detection(+Object, ?Time, -Detection) is nondet.
%
% Find all detections of the Object that are valid at time point Time
%
% @param Object     Object instance of interest
% @param Time       Time point of interest. If unbound, all detections of the object are returned.
% @param Detection  Detections of the object that are assumed to be valid at time Time
%
object_detection(Object, Time, Detection) :-

    findall([D_i,Object], (rdf_has(D_i, knowrob:objectActedOn, Object),
                           rdfs_individual_of(D_i,  knowrob:'MentalEvent')), Detections),

    member(P_O, Detections),
    nth0(0, P_O, Detection),
    nth0(1, P_O, Object),

    ((var(Time))
      -> (
        true
      ) ; (
        temporally_subsumes(Detection, Time)
    )).


%% temporally_subsumes(+Long, +Short) is nondet.
%
% Verify whether Long temporally subsumes Short
%
% @param Long   The longer time span (e.g. detection of an object)
% @param Short  The shorter time span (e.g. detection of an object)
%
temporally_subsumes(Long, Short) :-

      detection_starttime(Long, LongSt),!,
      detection_endtime(Long,   LongEt),!,

      detection_starttime(Short, ShortSt),!,
      detection_endtime(Short,   ShortEt),!,

      % compare the start and end times
      (ShortSt=<ShortEt),
      (LongSt=<ShortSt), (ShortSt<LongEt),
      (LongSt=<ShortEt), (ShortEt<LongEt).


%% detection_starttime(+Detection, -StartTime) is nondet.
%
% Determine the start time of an object detection as numerical value.
% Simply reads the asserted knowrob:startTime and transforms the timepoint
% into a numeric value.
%
% @param Detection  Instance of an event with asserted startTime
% @param StartTime  Numeric value describing the start time
%
detection_starttime(Detection, StartTime) :-

  % start time is asserted
  rdf_triple(knowrob:startTime, Detection, StartTtG),
  rdf_split_url(_, StartTt, StartTtG),
  atom_concat('timepoint_', StartTAtom, StartTt),
  term_to_atom(StartTime, StartTAtom).


%% detection_endtime(+Detection, -EndTime) is nondet.
%
% Determine the end time of an object detection as numerical value.
% If the knowrob:endTime is asserted, it is read and and transformed
% into a numeric value. Otherwise, the predicate searches for later
% perceptions of the same object and takes the startTime of the first
% subsequent detection as the endTime of the current detection. If
% there is neither an asserted endTime nor any later detection of the
% object, it is assumed that the observation is still valid and the
% current time + 1s is returned (to avoid problems with time glitches).
%
% @param Detection  Instance of an event
% @param EndTime    Numeric value describing the ent time
%
detection_endtime(Detection, EndTime) :-

  % end time is asserted
  rdf_triple(knowrob:endTime, Detection, EndTtG),
  rdf_split_url(_, EndTt, EndTtG),
  atom_concat('timepoint_', EndTAtom, EndTt),
  term_to_atom(EndTime, EndTAtom),!;

  % search for later detections of the object
  ( rdf_has(Detection, knowrob:objectActedOn, Object),
    rdf_has(LaterDetection, knowrob:objectActedOn, Object),
    LaterDetection \= Detection,
    rdfs_individual_of(LaterDetection,  knowrob:'MentalEvent'),
    rdf_triple(knowrob:startTime, Detection, StT),
    rdf_triple(knowrob:startTime, LaterDetection, EndTtG),
    rdf_triple(knowrob:after, StT, EndTtG),
    rdf_split_url(_, EndTt, EndTtG),
    atom_concat('timepoint_', EndTAtom, EndTt),
    term_to_atom(EndTime, EndTAtom),! );

  % otherwise take the current time (plus a second to avoid glitches)
  ( get_time(ET), EndTime is ET + 1.0).




%% compare_object_detections(-Delta, +P1, +P2) is det.
%
% Sort detections by their start time
%
% 
%
% @param Delta  One of '>', '<', '='
% @param P1     List [_, _, Time] as used in latest_detection_of_instance, latest_detection_of_type, latest_inferred_object_set
% @param P2     List [_, _, Time] as used in latest_detection_of_instance, latest_detection_of_type, latest_inferred_object_set
%
compare_object_detections(Delta, P1, P2) :-

    nth0(2, P1, St1),
    nth0(2, P2, St2),
    compare(Delta, St2, St1).

%% compare_inferences_by_prob(-Delta, +P1, +P2) is det.
%
% Sort inference results by their probability
% 
% @param Delta  One of '>', '<'
% @param P1     List [_, _, Time] as used in latest_detection_of_instance, latest_detection_of_type, latest_inferred_object_set
% @param P2     List [_, _, Time] as used in latest_detection_of_instance, latest_detection_of_type, latest_inferred_object_set
%

compare_inferences_by_prob('>', Inf1, Inf2) :-
  rdf_has(Inf1,knowrob:probability,Pr1), term_to_atom(P1,Pr1),
  rdf_has(Inf2,knowrob:probability,Pr2), term_to_atom(P2,Pr2),
  P1 < P2.

compare_inferences_by_prob('<', Inf1, Inf2) :-
  rdf_has(Inf1,knowrob:probability,Pr1), term_to_atom(P1,Pr1),
  rdf_has(Inf2,knowrob:probability,Pr2), term_to_atom(P2,Pr2),
  P1 >= P2.
