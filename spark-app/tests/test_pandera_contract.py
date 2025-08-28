import pandas as pd
import pandera as pa
import pytest

schema = pa.DataFrameSchema({
    "id": pa.Column(pa.Int, nullable=False),
    "value": pa.Column(pa.Float, nullable=False, checks=pa.Check.ge(0)),
})

def test_pandera_contract():
    df = pd.DataFrame({"id":[1,2,3], "value":[0.1, 1.2, 3.4]})
    schema.validate(df)  # should not raise
