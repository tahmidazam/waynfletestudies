function erp = erpcalc(samples)
    adddimension = cat(3, samples{:});
    erp = mean(adddimension, 3)';
end