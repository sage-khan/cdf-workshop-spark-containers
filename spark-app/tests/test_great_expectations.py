import pytest

try:
    import pandas as pd
    import great_expectations as ge
    GE_AVAILABLE = True
except Exception:
    GE_AVAILABLE = False

@pytest.mark.skipif(not GE_AVAILABLE, reason="great_expectations not installed")
def test_ge_expectations():
    import pandas as pd
    df = pd.DataFrame({"id":[1,2,3], "value":[10, 20, 30]})
    gdf = ge.from_pandas(df)
    # basic expectations
    assert gdf.expect_column_values_to_not_be_null("id")["success"]
    assert gdf.expect_column_min_to_be_between("value", min_value=0)["success"]
