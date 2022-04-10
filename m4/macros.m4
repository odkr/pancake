define(`concat', `$1$2')dnl
ifdef(`TAG', `', `define(TAG, concat(`v', VERSION))dnl')

