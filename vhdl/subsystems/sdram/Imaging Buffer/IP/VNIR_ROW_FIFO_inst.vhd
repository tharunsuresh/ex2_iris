VNIR_ROW_FIFO_inst : VNIR_ROW_FIFO PORT MAP (
		aclr	 => aclr_sig,
		clock	 => clock_sig,
		data	 => data_sig,
		rdreq	 => rdreq_sig,
		wrreq	 => wrreq_sig,
		empty	 => empty_sig,
		q	 => q_sig
	);
