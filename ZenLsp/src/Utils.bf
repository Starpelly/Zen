namespace System
{
	extension Result<T, TErr>
	{
		public mixin GetValueOrPassthrough<TOk>()
		{
			if (this case .Err(let err)) return Result<TOk, TErr>.Err(err);
			Value
		}
	}

	extension Result<T, TErr> where TErr : ZenLsp.Error, delete
	{
		public mixin GetValueOrLog(T defaultValue)
		{
			T value;

			if (this case .Err(let err))
			{
				ZenLsp.Logging.Log.Error("Error: {}", err.message);
				value = defaultValue;
				delete err;
			}
			else value = Value;

			value
		}
	}
}