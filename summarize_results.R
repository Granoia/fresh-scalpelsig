# functions to interpret / summarize the outputs of evaluate_10k_panel_results.R

source("GLOBAL_CONFIG.R")



print_guide <- function() {
	print("How to use this file:") 
	print("1) list_results_files()")
	print("2) run save_summary_df() on paste0(GLOBAL_SCRIPT_OUT, <file name from step 1>)")
}

print_guide()



# example:
# load_panel_results_df(paste0(GLOBAL_SCRIPT_OUT, "panel_results_df_15-Jun-2020_13-57.tsv"))
load_panel_results_df <- function(infile) {
	return(read.csv(infile, sep="\t"))
}

list_results_files <- function() {
	return(list.files(GLOBAL_SCRIPT_OUT, pattern=".tsv"))
}

list_gp_results_files <- function() {
	return(list.files(GLOBAL_GENERAL_PANEL_DIR, pattern=".tsv"))
}


# given results data frame df,
# get medians of the relevant chunks of the results
# i.e., subset the df by Signature, and within each signature by objective function
# take the mean result (auroc/aupr) for the obtained panel, MSK-IMPACT, and WES of each subset, and record them
mean_results_df <- function(df, with_baseline=FALSE, verbose=2) {
	sigs = sort(unique(df$Signature))
	n_sigs = length(sigs)	

	if (verbose >= 2) { 
		print(paste0("Found ", length(sigs), " distinct signatures in given df:")) 
		print(sigs)
	}
	

	Obj1.AUPR = numeric(n_sigs)
	Obj2.AUPR = numeric(n_sigs)
	Obj3.AUPR = numeric(n_sigs)
	
	MSK.IMPACT.AUPR = numeric(n_sigs)
	WES.AUPR = numeric(n_sigs)
	Signature = numeric(n_sigs)
	Eval.Mode = character(n_sigs)

	Percent.Active = numeric(n_sigs)

	Obj1.R.Spearman = numeric(n_sigs)
	Obj2.R.Spearman = numeric(n_sigs)
	Obj3.R.Spearman = numeric(n_sigs)
	
	MSK.R.Spearman = numeric(n_sigs)
	WES.R.Spearman = numeric(n_sigs)

	Obj1.N.Spearman = numeric(n_sigs)
	Obj2.N.Spearman = numeric(n_sigs)
	Obj3.N.Spearman = numeric(n_sigs)

	MSK.N.Spearman = numeric(n_sigs)
	WES.N.Spearman = numeric(n_sigs)

	if (with_baseline) {
		Baseline.Med = numeric(n_sigs)
		Baseline.Spearman = numeric(n_sigs)
	}


	# iterate through signatures
	i = 1
	for (s in sigs) {
		sig_df = df[df$Signature==s, ] # get entries in df with current signature

		# sanity check to make sure that all the observations in a signature are either AUROC or AUPR
		# (if both are within a single signature, then there is a problem)
		curr_eval_mode = as.character(sig_df$Eval.Mode)
		if (length( unique(curr_eval_mode) ) != 1) {
			print("Sanity check failed:")
			print(paste0("Signature ", s, " contained ", length(unique(curr_eval_mode)), " distinct entries for Eval.Mode"))	
			print(unique(curr_eval_mode))
			print(paste0("But it does not make sense to take the median across different evaluation metrics. Please supply a df such that each signature has only one eval_mode (either auroc OR aupr)."))
			stop()
		}
		em = curr_eval_mode[1]
		Eval.Mode[i] = em

		obj1_df = sig_df[sig_df$Obj.Fn==1, ] # get entries in df for obj fn 1, 2, 3
		obj2_df = sig_df[sig_df$Obj.Fn==2, ]
		obj3_df = sig_df[sig_df$Obj.Fn==3, ]

		obj1_res = obj1_df$Panel.AUPR
		obj2_res = obj2_df$Panel.AUPR
		obj3_res = obj3_df$Panel.AUPR

		if (with_baseline) {
			# test sets are the same across objective functions so one will suffice
			o2_bl = obj2_df$Baseline.Med
			bl_med = mean(o2_bl)

			Baseline.Med[i] = bl_med

			if ("BP.Spearman.Med" %in% colnames(df)) {
				o2_bl_sp = obj2_df$BP.Spearman.Med
				bl_sp_med = mean(o2_bl_sp)

				Baseline.Spearman[i] = bl_sp_med
			}
		}

		# the obj1, 2, and 3 dfs have the same test sets, so the benchmark panels repeat their results
		# so it is sufficient to just take 1 of the obj dfs.
		msk_impact_res = obj2_df$MSK.IMPACT.AUPR
		wes_res = obj2_df$WES.AUPR

		# get means across each subset of results
		obj1_med = mean(obj1_res)
		obj2_med = mean(obj2_res)
		obj3_med = mean(obj3_res)

		mski_med = mean(msk_impact_res)
		wes_med = mean(wes_res)
		
		# place scores into appropriate vectors

		Obj1.AUPR[i] = obj1_med
		Obj2.AUPR[i] = obj2_med
		Obj3.AUPR[i] = obj3_med

		MSK.IMPACT.AUPR[i] = mski_med
		WES.AUPR[i] = wes_med
		
		Signature[i] = s

		if ("Percent.Active" %in% colnames(df)) {
			Percent.Active[i] = obj2_df$Percent.Active[1]
		}

		# spearman score

		if ("Raw.Spearman" %in% colnames(df)) {
			Obj1.R.Spearman[i] = mean(obj1_df$Raw.Spearman)
			Obj2.R.Spearman[i] = mean(obj2_df$Raw.Spearman)
			Obj3.R.Spearman[i] = mean(obj3_df$Raw.Spearman)

			MSK.R.Spearman[i] = mean(obj2_df$MSK.R.Spearman)
			WES.R.Spearman[i] = mean(obj2_df$WES.R.Spearman)
		}
		if ("Norm.Spearman" %in% colnames(df)) {
			Obj1.N.Spearman[i] = mean(obj1_df$Norm.Spearman)
			Obj2.N.Spearman[i] = mean(obj2_df$Norm.Spearman)
			Obj3.N.Spearman[i] = mean(obj3_df$Norm.Spearman)
		
			MSK.N.Spearman[i] = mean(obj2_df$MSK.N.Spearman)
			WES.N.Spearman[i] = mean(obj2_df$WES.N.Spearman)
		}

		i = i + 1
	}
	
	if (!with_baseline) {
		results_df = data.frame(Signature, Obj1.AUPR, Obj2.AUPR, MSK.IMPACT.AUPR, WES.AUPR, Percent.Active)
		if ("Raw.Spearman" %in% colnames(df)) {
			results_df = data.frame(Signature, Obj1.R.Spearman, Obj2.R.Spearman, MSK.R.Spearman, WES.R.Spearman, Obj1.AUPR, Obj2.AUPR, MSK.IMPACT.AUPR, WES.AUPR, Percent.Active)
		}

	} else {
		results_df = data.frame(Signature, Obj1.AUPR, Obj2.AUPR, Baseline.Med, MSK.IMPACT.AUPR, WES.AUPR, Percent.Active)
		if ("Raw.Spearman" %in% colnames(df)) {
			results_df = data.frame(Signature, Obj1.R.Spearman, Obj2.R.Spearman, Baseline.Spearman, MSK.R.Spearman, WES.R.Spearman, Obj1.AUPR, Obj2.AUPR, Baseline.Med, MSK.IMPACT.AUPR, WES.AUPR, Percent.Active)
	}
	
	}

	return(results_df)
}



save_summary_df <- function(results_df_infile, with_baseline=FALSE, outfile=NULL) {
	print(paste0("Loading panel results df from ", results_df_infile))
	df = load_panel_results_df(results_df_infile)

	print("results df dimensions: ")
	print(dim(df))
	
	summary_df = mean_results_df(df, with_baseline=with_baseline)
	
	
	if (is.null(outfile)) {
		# use default outfile
		# this assumes that the infile was taken from GLOBAL_SCRIPT_OUT
		file = sub(GLOBAL_SCRIPT_OUT, "", results_df_infile) # remove file path from infile

		outfile = paste0(GLOBAL_SCRIPT_OUT, "SUMMARY_", file)
	}
	
	print(paste0("writing summary df to ", outfile))
	write.table(summary_df, file=outfile, sep="\t", quote=FALSE, row.names=FALSE)
}




################# GENERAL PANEL RESULTS SUMMARY #################


# single_panel_df should be the results from a SINGLE PANEL, e.g. a subset of the results df that shares the same File.Name
gp_msk_comparison_vec <- function(single_panel_df) {
	rs = single_panel_df$Panel.AUPR
	msk = single_panel_df$MSK.IMPACT.AUPR
	sigs = paste0("Sig.", single_panel_df$Signature)
	
	comp = rs - msk
	names(comp) = sigs
	return(comp)
}

gp_comparison_df <- function(gp_res_df) {
	Panel.File = unique(as.character(gp_res_df$File.Name))

	ret = c()

	# get each individual panel from gp_res_df
	for (f in Panel.File) {
		p_df = gp_res_df[ gp_res_df$File.Name == f, ]
		comp_vec = gp_msk_comparison_vec(p_df)
		ret = rbind(ret, comp_vec)
	}
	ret = as.data.frame(ret)
	ret = cbind(ret, Panel.File)
}
