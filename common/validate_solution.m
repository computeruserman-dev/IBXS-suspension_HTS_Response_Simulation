function validate_solution(t,Y,tOut,label)
% Reject early termination, shape errors and non-finite state output.
assert(isequal(size(Y),[numel(tOut),8]),'%s returned incomplete/eight-state output.',label);
assert(numel(t) == numel(tOut) && max(abs(t(:)-tOut(:))) < 1e-12, ...
    '%s did not complete the requested time grid.',label);
assert(all(isfinite(t(:))) && all(isfinite(Y(:))),'%s contains NaN or Inf.',label);
end
