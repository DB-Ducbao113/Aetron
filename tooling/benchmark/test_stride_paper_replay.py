import unittest
import numpy as np
from stride_paper_replay import extract_cycles, design, fit, predict

class ReplayTests(unittest.TestCase):
    def test_completed_cycle_uses_next_event_not_stale_label(self):
        # columns ax ay az timestamp_ms length counter cumulative_m
        a = np.array([[0,0,9,0,0,0,0], [0,0,9,10,.5,1,.5],
                      [0,0,11,510,1.2,1,.5], [0,0,9,1010,1.2,2,1.7],
                      [0,0,10,1510,1.3,2,1.7], [0,0,9,2010,1.3,3,3.0]])
        rows, rejected = extract_cycles(a)
        self.assertEqual(len(rows), 2)
        self.assertAlmostEqual(rows[0][3], 1.2)
        self.assertAlmostEqual(rows[0][1], 1)
        self.assertAlmostEqual(rows[0][2], 2)
        self.assertAlmostEqual(rows[1][3], 1.3)

    def test_counter_gap_is_not_a_single_stride(self):
        a = np.array([[0,0,9,-10,0,0,0], [0,0,9,0,1,1,1], [0,0,11,500,2,1,1],
                      [0,0,9,1000,2,3,3]])
        rows, rejected = extract_cycles(a)
        self.assertEqual(rows, [])
        self.assertEqual(rejected['counter_gap'], 1)

    def test_paper_equations_and_calibration(self):
        a = np.array([[0,1,1,1.5],[0,2,1024,5.0],[0,3,1,3.5]])
        x = design(a, 'cca2022')
        np.testing.assert_allclose(x, [[1,1],[4,2],[3,1]])
        np.testing.assert_allclose(predict(a,'cca2022',fit(a,'cca2022')), a[:,3])
        np.testing.assert_allclose(design(a,'pca2021').ravel(), [1,2,1])

if __name__ == '__main__':
    unittest.main()
